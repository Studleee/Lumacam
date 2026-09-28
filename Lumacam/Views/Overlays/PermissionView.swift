import SwiftUI

struct PermissionView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.lumaAccent)

            Text("Camera access is off")
                .font(.title2.bold())
                .foregroundStyle(Color.white)

            Text("Lumacam needs the camera to take photos and videos. You can turn on access in Settings.")
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.lumaAccent))
            }
        }
        .padding(40)
    }
}
