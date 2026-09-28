import SwiftUI

struct ModePicker: View {
    let selection: CaptureMode
    let onSelect: (CaptureMode) -> Void

    var body: some View {
        HStack(spacing: 28) {
            ForEach(CaptureMode.allCases) { mode in
                let isSelected = mode == selection
                Button {
                    onSelect(mode)
                } label: {
                    VStack(spacing: 4) {
                        Text(mode.title)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(isSelected ? Color.lumaAccent : Color.white.opacity(0.45))
                        Capsule()
                            .fill(isSelected ? Color.lumaAccent : Color.clear)
                            .frame(width: 20, height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
    }
}
