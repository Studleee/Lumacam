import Foundation
import LockedCameraCapture

/// Moves photos taken from the Lock Screen into the photo library and the Lumacam gallery.
@available(iOS 18, *)
enum LockedCaptureImporter {
    /// Returns the number of photos imported.
    @MainActor
    static func importCaptures(into gallery: GalleryStore) async throws -> Int {
        let manager = LockedCameraCaptureManager.shared
        var imported = 0
        for directory in manager.sessionContentURLs {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            )) ?? []
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                try await gallery.savePhoto(Data(contentsOf: file))
                imported += 1
            }
            try await manager.invalidateSessionContent(at: directory)
        }
        return imported
    }

    static func shareSettings(photoAspect: PhotoAspect, torchLevel: Float, isTorchOn: Bool) async {
        let context = LumacamCaptureContext(
            photoAspect: photoAspect.rawValue,
            torchLevel: torchLevel,
            isTorchOn: isTorchOn
        )
        try? await LumacamCaptureIntent.updateAppContext(context)
    }
}
