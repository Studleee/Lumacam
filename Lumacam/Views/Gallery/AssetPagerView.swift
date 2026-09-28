import AVKit
import Photos
import SwiftUI

/// Swipeable full-screen viewer for the gallery.
struct AssetPagerView: View {
    let store: GalleryStore
    @State private var selection: String
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(store: GalleryStore, initialIdentifier: String) {
        self.store = store
        _selection = State(initialValue: initialIdentifier)
    }

    private var currentAsset: PHAsset? {
        store.assets.first { $0.localIdentifier == selection }
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(store.assets, id: \.localIdentifier) { asset in
                AssetDetailView(asset: asset, isVisible: asset.localIdentifier == selection)
                    .tag(asset.localIdentifier)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(currentAsset?.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive, action: deleteCurrent) {
                    Image(systemName: "trash")
                }
                .disabled(currentAsset == nil)
            }
        }
        .alert("Couldn't delete", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteCurrent() {
        guard let asset = currentAsset,
              let index = store.assets.firstIndex(of: asset) else { return }
        Task {
            do {
                try await store.delete(asset)
                if store.assets.isEmpty {
                    dismiss()
                } else {
                    selection = store.assets[min(index, store.assets.count - 1)].localIdentifier
                }
            } catch let error as PHPhotosError where error.code == .userCancelled {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AssetDetailView: View {
    let asset: PHAsset
    let isVisible: Bool

    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if asset.mediaType == .video {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    ProgressView()
                }
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: asset.localIdentifier) {
            if asset.mediaType == .video {
                if let item = await PhotoLibrary.playerItem(for: asset) {
                    player = AVPlayer(playerItem: item)
                }
            } else {
                image = await PhotoLibrary.image(
                    for: asset,
                    targetSize: CGSize(width: 2400, height: 2400),
                    contentMode: .aspectFit
                )
            }
        }
        .onChange(of: isVisible) { _, visible in
            if !visible { player?.pause() }
        }
        .onDisappear { player?.pause() }
    }
}
