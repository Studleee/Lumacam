import AVFoundation
import ImageIO
import LockedCameraCapture
import Observation
import UIKit
import UniformTypeIdentifiers

/// A photo-only camera for the Lock Screen. The photo library isn't available while the phone is
/// locked, so captures are written to the session's content folder and imported by the app later.
@Observable @MainActor
final class LockedCameraModel {
    enum State { case starting, ready, needsPermission }

    private(set) var state: State = .starting
    private(set) var capabilities = CameraCapabilities()
    private(set) var zoom: CGFloat = 1
    private(set) var isTorchOn = true
    private(set) var torchLevel: Float = 1
    private(set) var photoAspect: PhotoAspect = .sixteenNine
    private(set) var lastCapture: UIImage?
    private(set) var focusPoint: CGPoint?
    private(set) var focusTapCount = 0
    private(set) var isShutterFlashing = false
    var errorMessage: String?

    let service = CameraService()
    @ObservationIgnored private let session: LockedCameraCaptureSession
    @ObservationIgnored private var pinchStartZoom: CGFloat = 1
    @ObservationIgnored private var pendingPhotoAspects: [PhotoAspect] = []

    init(session: LockedCameraCaptureSession) {
        self.session = session
    }

    var previewAspectRatio: CGFloat { 1 / photoAspect.longToShortRatio }

    func start() async {
        service.onEvent = { [weak self] event in self?.handle(event) }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            state = .needsPermission
            return
        }
        if let context = try? await LumacamCaptureIntent.appContext {
            photoAspect = PhotoAspect(rawValue: context.photoAspect) ?? .sixteenNine
            torchLevel = context.torchLevel
            isTorchOn = context.isTorchOn
        }
        state = .ready
        service.start(mode: .photo, torchLevel: isTorchOn ? torchLevel : 0)
    }

    func stop() {
        service.stop()
    }

    func openApp() async {
        let activity = NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
        try? await session.openApplication(for: activity)
    }

    // MARK: - Controls

    func toggleTorch() {
        isTorchOn.toggle()
        service.setTorch(level: isTorchOn ? torchLevel : 0)
    }

    func cyclePhotoAspect() {
        focusPoint = nil
        photoAspect = photoAspect.next
    }

    func switchCamera() {
        focusPoint = nil
        service.switchCamera()
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

    func focus(viewPoint: CGPoint, devicePoint: CGPoint) {
        focusPoint = viewPoint
        focusTapCount += 1
        service.focus(at: devicePoint)
    }

    func capture() {
        pendingPhotoAspects.append(photoAspect)
        service.capturePhoto()
    }

    // MARK: - Camera events

    private func handle(_ event: CameraEvent) {
        switch event {
        case .configured(let newCapabilities):
            capabilities = newCapabilities
            zoom = newCapabilities.zoom
        case .willCapturePhoto:
            isShutterFlashing = true
            Task {
                try? await Task.sleep(for: .milliseconds(90))
                isShutterFlashing = false
            }
        case .photoCaptured(let data):
            let aspect = pendingPhotoAspects.isEmpty ? photoAspect : pendingPhotoAspects.removeFirst()
            Task {
                let cropped = await Task.detached(priority: .userInitiated) {
                    PhotoCropper.crop(data, to: aspect)
                }.value
                save(cropped ?? data)
            }
        case .recordingStarted, .recordingFinished:
            break
        case .failed(let message):
            errorMessage = message
        }
    }

    private func save(_ data: Data) {
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
        let url = session.sessionContentURL
            .appendingPathComponent(name)
            .appendingPathExtension(Self.fileExtension(for: data))
        do {
            try data.write(to: url)
            if let image = UIImage(data: data) {
                lastCapture = image.preparingThumbnail(of: Self.thumbnailSize(for: image.size)) ?? image
            }
        } catch {
            errorMessage = "Couldn't save the photo."
        }
    }

    private static func fileExtension(for data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let fileExtension = UTType(identifier)?.preferredFilenameExtension else { return "heic" }
        return fileExtension
    }

    private static func thumbnailSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: 160, height: 160) }
        let scale = 160 / min(size.width, size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
