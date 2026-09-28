import Photos
import SwiftUI

struct GalleryView: View {
    let store: GalleryStore
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if store.assets.isEmpty {
                    ContentUnavailableView(
                        "No captures yet",
                        systemImage: "camera",
                        description: Text(PhotoLibrary.canRead
                            ? "Photos and videos you take with Lumacam show up here."
                            : "Allow photo library access in Settings to see your captures here.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(store.assets, id: \.localIdentifier) { asset in
                                NavigationLink(value: asset.localIdentifier) {
                                    AssetThumbnailView(asset: asset)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lumacam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { identifier in
                AssetPagerView(store: store, initialIdentifier: identifier)
            }
        }
        .preferredColorScheme(.dark)
        .tint(.lumaAccent)
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Color.white.opacity(0.08)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Text(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .shadow(radius: 2)
                        .padding(5)
                }
            }
            .task(id: asset.localIdentifier) {
                image = await PhotoLibrary.image(for: asset, targetSize: CGSize(width: 300, height: 300))
            }
    }
}
