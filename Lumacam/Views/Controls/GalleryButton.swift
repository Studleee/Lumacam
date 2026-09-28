import SwiftUI

struct GalleryButton: View {
    let thumbnail: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                            .id(ObjectIdentifier(thumbnail))
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: thumbnail.map(ObjectIdentifier.init))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gallery")
    }
}
