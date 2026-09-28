import SwiftUI

/// Rule-of-thirds grid.
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Path { path in
                for third in [1.0 / 3.0, 2.0 / 3.0] {
                    path.move(to: CGPoint(x: size.width * third, y: 0))
                    path.addLine(to: CGPoint(x: size.width * third, y: size.height))
                    path.move(to: CGPoint(x: 0, y: size.height * third))
                    path.addLine(to: CGPoint(x: size.width, y: size.height * third))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
