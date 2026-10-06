import SwiftUI

/// A horizontal zoom ruler. Drag to zoom, flick to coast, tap a lens label to jump to it.
/// The ruler is logarithmic so each doubling of zoom takes the same distance.
struct ZoomDial: View {
    let zoom: CGFloat
    let range: ClosedRange<CGFloat>
    let lenses: [CGFloat]
    /// Called with the new zoom and whether the camera should ramp smoothly to it.
    let onChange: (CGFloat, Bool) -> Void

    @State private var dragStartZoom: CGFloat?

    static let pointsPerStop: CGFloat = 96
    private static let snapDistance: CGFloat = 0.08

    var body: some View {
        VStack(spacing: 4) {
            Text(Self.label(for: zoom) + "×")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.lumaAccent)

            DialRuler(
                logZoom: log2(zoom),
                range: range,
                lenses: lenses,
                onSelectLens: { lens in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        onChange(lens, true)
                    }
                }
            )
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(drag)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.2),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .padding(.horizontal, 16)
        .sensoryFeedback(.selection, trigger: lensBand)
        .accessibilityElement()
        .accessibilityLabel("Zoom")
        .accessibilityValue(Self.label(for: zoom) + "×")
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = direction == .increment ? 1.25 : 0.8
            onChange(clamped(zoom * step), true)
        }
    }

    /// Changes whenever the zoom crosses a lens, which drives the haptic tick.
    private var lensBand: Int {
        lenses.lastIndex { zoom >= $0 - 0.005 } ?? -1
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStartZoom ?? zoom
                if dragStartZoom == nil { dragStartZoom = zoom }
                onChange(zoom(from: start, translation: value.translation.width), false)
            }
            .onEnded { value in
                let start = dragStartZoom ?? zoom
                dragStartZoom = nil
                let target = snapped(zoom(from: start, translation: value.predictedEndTranslation.width))
                guard abs(target - zoom) > 0.001 else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onChange(target, true)
                }
            }
    }

    private func zoom(from start: CGFloat, translation: CGFloat) -> CGFloat {
        clamped(start * pow(2, -translation / Self.pointsPerStop))
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func snapped(_ value: CGFloat) -> CGFloat {
        let nearest = lenses.min { abs(log2($0) - log2(value)) < abs(log2($1) - log2(value)) }
        guard let nearest, abs(log2(nearest) - log2(value)) < Self.snapDistance else { return value }
        return nearest
    }

    /// Formats like the system camera: "1", "2.5", ".5".
    static func label(for value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        var text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        if text.hasPrefix("0.") { text.removeFirst() }
        return text
    }
}

private struct DialRuler: View, Animatable {
    var logZoom: CGFloat
    let range: ClosedRange<CGFloat>
    let lenses: [CGFloat]
    let onSelectLens: (CGFloat) -> Void

    var animatableData: CGFloat {
        get { logZoom }
        set { logZoom = newValue }
    }

    private static let ticksPerStop: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let midX = geometry.size.width / 2
            let tickY: CGFloat = 12

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let minLog = log2(range.lowerBound)
                    let maxLog = log2(range.upperBound)
                    let first = Int((minLog * Self.ticksPerStop).rounded(.up))
                    let last = Int((maxLog * Self.ticksPerStop).rounded(.down))
                    guard first <= last else { return }

                    for index in first...last {
                        let x = xPosition(for: CGFloat(index) / Self.ticksPerStop, midX: midX)
                        guard x >= 0, x <= size.width else { continue }
                        let rect = CGRect(x: x - 0.5, y: tickY, width: 1, height: 8)
                        context.fill(Path(rect), with: .color(.white.opacity(0.45)))
                    }
                    for lens in lenses {
                        let x = xPosition(for: log2(lens), midX: midX)
                        let rect = CGRect(x: x - 0.75, y: tickY - 3, width: 1.5, height: 14)
                        context.fill(Path(rect), with: .color(.white))
                    }
                }

                ForEach(lenses, id: \.self) { lens in
                    Text(ZoomDial.label(for: lens))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(width: 32, height: 20)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectLens(lens) }
                        .position(x: xPosition(for: log2(lens), midX: midX), y: tickY + 24)
                }

                Capsule()
                    .fill(Color.lumaAccent)
                    .frame(width: 2, height: 22)
                    .position(x: midX, y: tickY + 4)
                    .allowsHitTesting(false)
            }
        }
    }

    private func xPosition(for log: CGFloat, midX: CGFloat) -> CGFloat {
        midX + (log - logZoom) * ZoomDial.pointsPerStop
    }
}
