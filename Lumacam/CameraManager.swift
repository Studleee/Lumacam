import Foundation
import AVFoundation
import SwiftUI
import Photos

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var videoDevice: AVCaptureDevice?

    @Published var isTorchOn: Bool = false
    @Published var torchLevel: Float = 1.0
    @Published var capturedImage: UIImage?
    @Published var isRecording: Bool = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var currentMode: CaptureMode = .photo

    enum CaptureMode { case photo, video }

    private var currentCameraPosition: AVCaptureDevice.Position = .back

    func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        setupCamera(position: .back)

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setTorchLevel(level: 1.0)
            }
        }
    }

    private func setupCamera(position: AVCaptureDevice.Position) {
        // On iPhone 13, builtInWideAngleCamera IS the main 1x lens.
        // builtInDualWideCamera would pick the ultrawide as the base, causing zoomed-in "1x".
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        guard let videoDevice = videoDevice else { return }
        self.videoDevice = videoDevice

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if let currentInput = videoDeviceInput { session.removeInput(currentInput) }
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
                currentCameraPosition = position

                try videoDevice.lockForConfiguration()
                videoDevice.videoZoomFactor = 1.0
                videoDevice.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = 1.0 }
            }
        } catch { print("Camera input error: \(error)") }
    }

    func toggleTorch() {
        if isTorchOn {
            setTorchLevel(level: 0)
        } else {
            setTorchLevel(level: torchLevel > 0 ? torchLevel : 1.0)
        }
    }

    func setTorchLevel(level: Float) {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if level > 0 {
                try device.setTorchModeOn(level: level)
                DispatchQueue.main.async { self.isTorchOn = true; self.torchLevel = level }
            } else {
                device.torchMode = .off
                DispatchQueue.main.async { self.isTorchOn = false }
            }
            device.unlockForConfiguration()
        } catch { print("Torch error: \(error)") }
    }

    func setZoomFactor(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let clamped = max(1.0, min(factor, maxZoom))
            device.videoZoomFactor = clamped
            DispatchQueue.main.async { self.zoomFactor = clamped }
            device.unlockForConfiguration()
        } catch { print("Zoom error: \(error)") }
    }

    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.capturedImage = image }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
        }
    }

    func toggleVideoRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        } else {
            let filePath = FileManager.default.temporaryDirectory.appendingPathComponent("video_\(UUID().uuidString).mov")
            movieOutput.startRecording(to: filePath, recordingDelegate: self)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { self.isRecording = true }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { self.isRecording = false }
        guard error == nil else { return }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            }
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        session.beginConfiguration()
        setupCamera(position: newPosition)
        session.commitConfiguration()
        if newPosition == .back && isTorchOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.setTorchLevel(level: self.torchLevel)
            }
        }
    }
}
