import AVFoundation
import Observation
import Photos
import UIKit

/// The photos and videos captured with Lumacam, newest first. Only asset identifiers are stored;
/// the media itself lives in the user's photo library.
@Observable @MainActor
final class GalleryStore {
    private(set) var assets: [PHAsset] = []
    private(set) var latestThumbnail: UIImage?

    @ObservationIgnored private var identifiers: [String] {
        didSet { UserDefaults.standard.set(identifiers, forKey: Self.defaultsKey) }
    }

    private static let defaultsKey = "capturedAssetIdentifiers"
    private static let maxStoredCaptures = 500
    private static let thumbnailSize = CGSize(width: 160, height: 160)

    init() {
        identifiers = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
    }

    /// Re-fetches assets, dropping any that were deleted outside the app.
    func reload() async {
        guard PhotoLibrary.canRead, !identifiers.isEmpty else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        let byIdentifier = Dictionary(
            result.objects(at: IndexSet(integersIn: 0..<result.count)).map { ($0.localIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        assets = identifiers.compactMap { byIdentifier[$0] }
        identifiers = assets.map(\.localIdentifier)
        await refreshLatestThumbnail()
    }

    func savePhoto(_ data: Data) async throws {
        if let image = UIImage(data: data) {
            latestThumbnail = await image.byPreparingThumbnail(ofSize: Self.aspectFitSize(for: image.size))
        }
        let identifier = try await PhotoLibrary.savePhoto(data)
        insert(identifier)
    }

    func saveVideo(at url: URL) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)
        if let frame = try? await generator.image(at: .zero).image {
            latestThumbnail = UIImage(cgImage: frame)
        }
        let identifier = try await PhotoLibrary.saveVideo(at: url)
        insert(identifier)
    }

    func delete(_ asset: PHAsset) async throws {
        try await PhotoLibrary.delete(asset)
        assets.removeAll { $0.localIdentifier == asset.localIdentifier }
        identifiers.removeAll { $0 == asset.localIdentifier }
        await refreshLatestThumbnail()
    }

    private func insert(_ identifier: String) {
        identifiers.insert(identifier, at: 0)
        if identifiers.count > Self.maxStoredCaptures {
            identifiers.removeLast(identifiers.count - Self.maxStoredCaptures)
        }
        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject {
            assets.insert(asset, at: 0)
        }
    }

    private func refreshLatestThumbnail() async {
        guard let latest = assets.first else {
            latestThumbnail = nil
            return
        }
        latestThumbnail = await PhotoLibrary.image(for: latest, targetSize: Self.thumbnailSize)
    }

    private static func aspectFitSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return thumbnailSize }
        let scale = thumbnailSize.width * 2 / min(size.width, size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
