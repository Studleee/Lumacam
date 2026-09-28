import SwiftUI

struct TopBar: View {
    let model: CameraViewModel

    var body: some View {
        HStack(spacing: 12) {
            CircleIconButton(
                systemName: model.isTorchOn ? "bolt.fill" : "bolt.slash.fill",
                isActive: model.isTorchOn && model.capabilities.hasTorch,
                action: model.toggleTorch
            )
            .disabled(!model.capabilities.hasTorch)
            .opacity(model.capabilities.hasTorch ? 1 : 0.4)

            CircleIconButton(
                systemName: "timer",
                isActive: model.selfTimer != .off,
                badge: model.selfTimer == .off ? nil : "\(model.selfTimer.rawValue)s",
                action: model.cycleSelfTimer
            )
            .disabled(model.isBusy)

            Spacer()

            if let start = model.recordingStartedAt {
                RecordingBadge(start: start)
            }

            Spacer()

            CircleIconButton(systemName: "grid", isActive: model.showsGrid, action: model.toggleGrid)

            CircleIconButton(systemName: "slider.horizontal.3", isActive: model.showsAdjustments) {
                model.showsAdjustments.toggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

private struct RecordingBadge: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text(Self.format(context.date.timeIntervalSince(start)))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.5)))
        }
    }

    private static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
