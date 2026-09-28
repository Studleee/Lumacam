import AVFoundation
import UIKit

enum CameraEvent {
    case configured(CameraCapabilities)
    case willCapturePhoto
    case photoCaptured(Data)
    case recordingStarted
    case recordingFinished(URL?)
    case failed(String)
}

/// Owns the `AVCaptureSession`. Every session and device mutation happens on `sessionQueue`;
/// results are reported back on the main actor through `onEvent`.
final class CameraService: NSObject {
    let session = AVCaptureSession()
    var onEvent: (@MainActor (CameraEvent) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.lumacam.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var mode: CaptureMode = .photo

    /// Device zoom factor that corresponds to 1x. Virtual devices that include the ultra-wide
    /// camera start at the ultra-wide, so 1x sits at their first switch-over factor.
    private var zoomBase: CGFloat = 1
    private var zoom: CGFloat = 1
    private var exposureBias: Float = 0
    private var torchLevel: Float = 0

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        observeNotifications()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Lifecycle

    func start(mode: CaptureMode, torchLevel: Float) {
        sessionQueue.async { [self] in
            self.mode = mode
            self.torchLevel = torchLevel
            if !isConfigured {
                configureSession()
            }
            if isConfigured, !session.isRunning {
                session.startRunning()
            }
            applyTorch()
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        sessionQueue.async { [self] in
            previewLayer = layer
            makeRotationCoordinator()
        }
    }

    // MARK: - Configuration

    private func configureSession() {
        guard let device = Self.bestDevice(for: .back) else {
            emit(.failed("No camera is available on this device."))
            return
        }
        session.beginConfiguration()
        session.sessionPreset = mode == .photo ? .photo : .high
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        setVideoDevice(device)
        if mode == .video {
            addVideoRecordingComponents()
        }
        session.commitConfiguration()
        isConfigured = true
        emitConfiguration()
    }

    private func setVideoDevice(_ newDevice: AVCaptureDevice) {
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: newDevice)
        } catch {
            emit(.failed("Couldn't open the camera: \(error.localizedDescription)"))
            return
        }

        if let videoInput { session.removeInput(videoInput) }
        guard session.canAddInput(input) else {
            if let videoInput { session.addInput(videoInput) }
            emit(.failed("Couldn't switch cameras."))
            return
        }
        session.addInput(input)
        videoInput = input
        device = newDevice
        zoomBase = Self.zoomBase(for: newDevice)
        zoom = 1
        exposureBias = 0

        withLockedDevice { device in
            device.videoZoomFactor = zoomBase
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.setExposureTargetBias(0, completionHandler: nil)
        }
        makeRotationCoordinator()
    }

    private func addVideoRecordingComponents() {
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        if let connection = movieOutput.connection(with: .video), connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
        if audioInput == nil,
           AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let microphone = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(input) {
            session.addInput(input)
            audioInput = input
        }
    }

    private func removeVideoRecordingComponents() {
        session.removeOutput(movieOutput)
        if let audioInput {
            session.removeInput(audioInput)
            self.audioInput = nil
        }
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
    }

    /// Changing the session preset can reset the device format, so zoom and exposure are reapplied.
    private func reapplyDeviceSettings() {
        withLockedDevice { device in
            device.videoZoomFactor = clampedDeviceZoom(zoom, for: device)
            device.setExposureTargetBias(exposureBias, completionHandler: nil)
        }
        applyTorch()
    }

    // MARK: - Controls

    func setMode(_ newMode: CaptureMode) {
        sessionQueue.async { [self] in
            guard newMode != mode else { return }
            mode = newMode
            guard isConfigured else { return }
            session.beginConfiguration()
            if newMode == .video {
                addVideoRecordingComponents()
            } else {
                removeVideoRecordingComponents()
            }
            session.commitConfiguration()
            reapplyDeviceSettings()
            emitConfiguration()
        }
    }

    func switchCamera() {
        sessionQueue.async { [self] in
            guard isConfigured, !movieOutput.isRecording else { return }
            let position: AVCaptureDevice.Position = device?.position == .front ? .back : .front
            guard let newDevice = Self.bestDevice(for: position) else { return }
            session.beginConfiguration()
            setVideoDevice(newDevice)
            if mode == .video, let connection = movieOutput.connection(with: .video),
               connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            session.commitConfiguration()
            applyTorch()
            emitConfiguration()
        }
    }

    func setZoom(_ displayZoom: CGFloat, animated: Bool) {
        sessionQueue.async { [self] in
            zoom = displayZoom
            withLockedDevice { device in
                let factor = clampedDeviceZoom(displayZoom, for: device)
                if animated {
                    device.ramp(toVideoZoomFactor: factor, withRate: 8)
                } else {
                    device.cancelVideoZoomRamp()
                    device.videoZoomFactor = factor
                }
            }
        }
    }

    func setTorch(level: Float) {
        sessionQueue.async { [self] in
            torchLevel = level
            applyTorch()
        }
    }

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [self] in
            exposureBias = bias
            withLockedDevice { device in
                let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clamped, completionHandler: nil)
            }
        }
    }

    /// `devicePoint` is in the capture device's normalized coordinate space (0...1).
    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [self] in
            withLockedDevice { device in
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
            }
        }
    }

    private func resetFocusToCenter() {
        let center = CGPoint(x: 0.5, y: 0.5)
        withLockedDevice { device in
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = center
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = center
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
        }
    }

    private func applyTorch() {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        withLockedDevice { device in
            if torchLevel > 0 {
                try? device.setTorchModeOn(level: min(max(torchLevel, 0.01), AVCaptureDevice.maxAvailableTorchLevel))
            } else if device.torchMode != .off {
                device.torchMode = .off
            }
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        sessionQueue.async { [self] in
            guard isConfigured, session.isRunning else { return }
            applyCaptureRotation(to: photoOutput.connection(with: .video))
            let settings: AVCapturePhotoSettings
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.photoQualityPrioritization = .balanced
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleRecording() {
        sessionQueue.async { [self] in
            if movieOutput.isRecording {
                movieOutput.stopRecording()
                return
            }
            guard session.outputs.contains(movieOutput) else { return }
            applyCaptureRotation(to: movieOutput.connection(with: .video))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("lumacam-\(UUID().uuidString)")
                .appendingPathExtension("mov")
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    // MARK: - Helpers

    private func withLockedDevice(_ body: (AVCaptureDevice) -> Void) {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            body(device)
            device.unlockForConfiguration()
        } catch {
            print("Lumacam: couldn't lock camera for configuration: \(error)")
        }
    }

    private func clampedDeviceZoom(_ displayZoom: CGFloat, for device: AVCaptureDevice) -> CGFloat {
        min(max(displayZoom * zoomBase, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
    }

    private func makeRotationCoordinator() {
        guard let device else { return }
        let layer = previewLayer
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotationCoordinator = coordinator
        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]
        ) { [weak layer] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            DispatchQueue.main.async {
                guard let connection = layer?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
                connection.videoRotationAngle = angle
            }
        }
    }

    private func applyCaptureRotation(to connection: AVCaptureConnection?) {
        guard let connection, let rotationCoordinator else { return }
        let angle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    private func emitConfiguration() {
        guard let device else { return }
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) / zoomBase }
        let hasTelephoto = device.constituentDevices.contains { $0.deviceType == .builtInTelephotoCamera }
        let telephoto = hasTelephoto ? switchOvers.last : nil
        let minZoom = device.minAvailableVideoZoomFactor / zoomBase
        let maxZoom = max(1, min(device.maxAvailableVideoZoomFactor / zoomBase, (telephoto ?? 2) * 5))
        let lenses = device.position == .back
            ? CameraCapabilities.lensPresets(minZoom: minZoom, maxZoom: maxZoom, telephoto: telephoto)
            : [1]

        let capabilities = CameraCapabilities(
            position: device.position,
            lenses: lenses,
            zoomRange: minZoom...maxZoom,
            exposureRange: max(device.minExposureTargetBias, -2)...min(device.maxExposureTargetBias, 2),
            hasTorch: device.hasTorch,
            zoom: min(max(zoom, minZoom), maxZoom),
            exposureBias: exposureBias
        )
        emit(.configured(capabilities))
    }

    private func emit(_ event: CameraEvent) {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.onEvent?(event)
            }
        }
    }

    private func observeNotifications() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            sessionQueue.async { self.resetFocusToCenter() }
        })

        // The torch switches off whenever the session is interrupted (for example, when the app
        // goes to the background), so turn it back on when capture resumes.
        for name in [AVCaptureSession.didStartRunningNotification, AVCaptureSession.interruptionEndedNotification] {
            observers.append(center.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                guard let self else { return }
                sessionQueue.async { self.applyTorch() }
            })
        }

        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            sessionQueue.async {
                if error?.code == .mediaServicesWereReset, !self.session.isRunning {
                    self.session.startRunning()
                } else {
                    self.emit(.failed("The camera stopped unexpectedly."))
                }
            }
        })
    }

    private static func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position).devices
        for type in types {
            if let device = devices.first(where: { $0.deviceType == type }) { return device }
        }
        return nil
    }

    private static func zoomBase(for device: AVCaptureDevice) -> CGFloat {
        guard device.constituentDevices.contains(where: { $0.deviceType == .builtInUltraWideCamera }),
              let firstSwitchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first else { return 1 }
        return CGFloat(truncating: firstSwitchOver)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        emit(.willCapturePhoto)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(), error == nil {
            emit(.photoCaptured(data))
        } else {
            emit(.failed("Couldn't capture the photo."))
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        emit(.recordingStarted)
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        var succeeded = error == nil
        if let error = error as NSError?,
           let finished = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool {
            succeeded = finished
        }
        emit(.recordingFinished(succeeded ? outputFileURL : nil))
        if !succeeded {
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }
}
