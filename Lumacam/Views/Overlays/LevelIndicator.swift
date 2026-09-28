import SwiftUI

/// A horizon line that follows the real horizon and turns yellow when the phone is level.
struct LevelIndicator: View {
    let level: LevelMonitor

    private static let visibleRange = 15.0 * .pi / 180

    var body: some View {
        let isLevel = level.isLevel
        ZStack {
            HStack(spacing: 96) {
                referenceTick
                referenceTick
            }
            .opacity(isLevel ? 0 : 1)

            Capsule()
                .fill(isLevel ? Color.lumaAccent : Color.white)
                .frame(width: isLevel ? 152 : 84, height: 1.5)
                .rotationEffect(.radians(-level.deviation))
        }
        .rotationEffect(.radians(-level.nearestLevelAngle))
        .opacity(level.isUpright && abs(level.deviation) < Self.visibleRange ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isLevel)
        .allowsHitTesting(false)
    }

    private var referenceTick: some View {
        Capsule()
            .fill(Color.white.opacity(0.8))
            .frame(width: 28, height: 1.5)
    }
}
