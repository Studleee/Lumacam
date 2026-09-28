import SwiftUI

struct FocusIndicator: View {
    let point: CGPoint

    @State private var scale = 1.5
    @State private var opacity = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Color.lumaAccent, lineWidth: 1.5)
            .frame(width: 76, height: 76)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(point)
            .allowsHitTesting(false)
            .task {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { scale = 1 }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.4)) { opacity = 0.35 }
            }
    }
}
