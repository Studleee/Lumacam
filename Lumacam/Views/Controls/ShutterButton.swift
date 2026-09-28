import SwiftUI

struct ShutterButton: View {
    let mode: CaptureMode
    let isRecording: Bool
    let isCountingDown: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 76, height: 76)

                if isRecording || isCountingDown {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.red : Color.white)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(mode == .video ? Color.red : Color.lumaAccent)
                        .frame(width: 60, height: 60)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRecording)
            .animation(.easeInOut(duration: 0.2), value: isCountingDown)
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isCountingDown { return "Cancel timer" }
        if isRecording { return "Stop recording" }
        return mode == .photo ? "Take photo" : "Start recording"
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}
