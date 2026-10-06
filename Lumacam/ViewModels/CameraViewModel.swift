import AVFoundation
import Observation
import SwiftUI

@Observable @MainActor
final class CameraViewModel {
    enum Authorization { case unknown, authorized, denied }

    enum SelfTimer: Int, CaseIterable {
        case off = 0, three = 3, ten = 10

        var next: SelfTimer {
            let all = Self.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    private(set) var authorization: Authorization = .unknown
    private(set) var capabilities = CameraCapabilities()
    private(set) var mode: CaptureMode = .photo
    private(set) var zoom: CGFloat = 1
    private(set) var exposureBias: Float = 0
    private(set) var isTorchOn = true
    private(set) var torchLevel: Float = 1
    private(set) var isRecording = false
    private(set) var recordingStartedAt: Date?
    private(set) var countdown: Int?
    private(set) var focusPoint: CGPoint?
    private(set) var focusTapCount = 0
    private(set) var isShutterFlashing = false
    var selfTimer: SelfTimer = .off
    private(set) var photoAspect: PhotoAspect = PhotoAspect(
        rawValue: UserDefaults.standard.string(forKey: "photoAspect") ?? ""
    ) ?? .sixteenNine {
        didSet { UserDefaults.standard.set(photoAspect.rawValue, forKey: "photoAspect") }
    }
    var showsGrid = false
    var showsAdjustments = false
    var errorMessage: String?

    let service = CameraService()
    let gallery = GalleryStore()
    let level = LevelMonitor()

    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var pinchStartZoom: CGFloat = 1
    /// Aspect ratio chosen at the moment each in-flight photo was taken, oldest first.
    @ObservationIgnored private var pendingPhotoAspects: [PhotoAspect] = []

    /// Controls that would disrupt a capture in progress are locked while this is true.
    var isBusy: Bool { isRecording || countdown != nil }

    /// Width over height of the preview frame, which matches what gets saved.
    var previewAspectRatio: CGFloat {
        switch mode {
        case .photo: 1 / photoAspect.longToShortRatio
        case .video: 9.0 / 16.0
        }
    }

    // MARK: - Lifecycle

    func start() async {
        service.onEvent = { [weak self] event in self?.handle(event) }

        guard await Self.requestCameraAccess() else {
            authorization = .denied
            return
        }
        authorization = .authorized
        service.start(mode: mode, torchLevel: isTorchOn ? torchLevel : 0)
        await gallery.reload()
    }

    private static func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    // MARK: - Controls

    func setMode(_ newMode: CaptureMode) {
        guard newMode != mode, !isBusy else { return }
        mode = newMode
        focusPoint = nil
        Task {
            if newMode == .video, AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
            service.setMode(newMode)
        }
    }

    /// Puts the camera in the state requested by a Control Center, Lock Screen, or Shortcuts launch.
    func applyQuickLaunch(_ launch: QuickLaunchMode) {
        guard authorization == .authorized, !isBusy else { return }
        setMode(launch == .video ? .video : .photo)
        let wantsFront = launch == .selfie
        if (capabilities.position == .front) != wantsFront {
            switchCamera()
        }
    }

    func switchCamera() {
        guard !isBusy else { return }
        focusPoint = nil
        service.switchCamera()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        service.setTorch(level: isTorchOn ? torchLevel : 0)
    }

    func setTorchLevel(_ level: Float) {
        torchLevel = level
        isTorchOn = true
        service.setTorch(level: level)
    }

    func setZoom(_ value: CGFloat, animated: Bool = false) {
        let range = capabilities.zoomRange
        zoom = min(max(value, range.lowerBound), range.upperBound)
        service.setZoom(zoom, animated: animated)
    }

    func beginPinch() {
        pinchStartZoom = zoom
    }

    func pinch(scale: CGFloat) {
        setZoom(pinchStartZoom * scale)
    }

    func setExposureBias(_ bias: Float) {
        exposureBias = bias
        service.setExposureBias(bias)
    }

    func focus(viewPoint: CGPoint, devicePoint: CGPoint) {
        focusPoint = viewPoint
        focusTapCount += 1
        service.focus(at: devicePoint)
    }

    func toggleGrid() {
        showsGrid.toggle()
        showsGrid ? level.start() : level.stop()
    }

    func cyclePhotoAspect() {
        guard !isBusy else { return }
        focusPoint = nil
        photoAspect = photoAspect.next
    }

    func cycleSelfTimer() {
        selfTimer = selfTimer.next
    }

    // MARK: - Capture

    func shutterTapped() {
        if countdown != nil {
            cancelCountdown()
        } else if isRecording {
            service.toggleRecording()
        } else if selfTimer == .off {
            capture()
        } else {
            startCountdown(from: selfTimer.rawValue)
        }
    }

    private func capture() {
        switch mode {
        case .photo:
            pendingPhotoAspects.append(photoAspect)
            service.capturePhoto()
        case .video: service.toggleRecording()
        }
    }

    private func startCountdown(from seconds: Int) {
        countdownTask = Task {
            for remaining in stride(from: seconds, to: 0, by: -1) {
                countdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            countdown = nil
            capture()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    // MARK: - Camera events

    private func handle(_ event: CameraEvent) {
        switch event {
        case .configured(let newCapabilities):
            capabilities = newCapabilities
            zoom = newCapabilities.zoom
            exposureBias = newCapabilities.exposureBias
        case .willCapturePhoto:
            flashShutter()
        case .photoCaptured(let data):
            let aspect = pendingPhotoAspects.isEmpty ? photoAspect : pendingPhotoAspects.removeFirst()
            Task {
                let cropped = await Task.detached(priority: .userInitiated) {
                    PhotoCropper.crop(data, to: aspect)
                }.value
                await save { try await self.gallery.savePhoto(cropped ?? data) }
            }
        case .recordingStarted:
            isRecording = true
            recordingStartedAt = .now
        case .recordingFinished(let url):
            isRecording = false
            recordingStartedAt = nil
            if let url {
                Task { await save { try await self.gallery.saveVideo(at: url) } }
            } else {
                errorMessage = "The recording couldn't be finished."
            }
        case .failed(let message):
            errorMessage = message
        }
    }

    private func flashShutter() {
        isShutterFlashing = true
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            isShutterFlashing = false
        }
    }

    private func save(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
