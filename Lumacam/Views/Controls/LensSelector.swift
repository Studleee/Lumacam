import SwiftUI

struct LensSelector: View {
    let lenses: [CGFloat]
    let zoom: CGFloat
    let activeLens: CGFloat
    let onSelect: (CGFloat) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(lenses, id: \.self) { lens in
                let isActive = lens == activeLens
                Button {
                    onSelect(lens)
                } label: {
                    Text(isActive ? Self.label(for: zoom) + "×" : Self.label(for: lens))
                        .font(.system(size: isActive ? 13 : 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isActive ? Color.lumaAccent : Color.white)
                        .frame(width: isActive ? 40 : 32, height: isActive ? 40 : 32)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Capsule().fill(Color.white.opacity(0.1)))
        .animation(.easeInOut(duration: 0.15), value: activeLens)
    }

    /// Formats like the system camera: "1", "2.5", ".5".
    static func label(for value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        var text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        if text.hasPrefix("0.") { text.removeFirst() }
        return text
    }
}
