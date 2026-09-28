import AVFoundation
import Photos
import UIKit

enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Lumacam doesn't have access to your photo library. You can allow it in Settings."
        case .saveFailed: "The capture couldn't be saved to your photo library."
        }
    }
}

enum PhotoLibrary {
    static var canRead: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Returns the local identifier of the new asset.
    static func savePhoto(_ data: Data) async throws -> String {
        try await createAsset { request in
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    /// Moves the file at `url` into the library and returns the local identifier of the new asset.
    static func saveVideo(at url: URL) async throws -> String {
        try await createAsset { request in
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            request.addResource(with: .video, fileURL: url, options: options)
        }
    }

    static func delete(_ asset: PHAsset) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
    }

    static func image(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize, contentMode: contentMode, options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    static func playerItem(for asset: PHAsset) async -> AVPlayerItem? {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private final class IdentifierBox: @unchecked Sendable {
        var identifier: String?
    }

    private static func createAsset(_ configure: @escaping (PHAssetCreationRequest) -> Void) async throws -> String {
        guard await requestAccess() else { throw PhotoLibraryError.accessDenied }
        let box = IdentifierBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            configure(request)
            box.identifier = request.placeholderForCreatedAsset?.localIdentifier
        }
        guard let identifier = box.identifier else { throw PhotoLibraryError.saveFailed }
        return identifier
    }
}
