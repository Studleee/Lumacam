import SwiftUI

struct AdjustmentsPanel: View {
    let model: CameraViewModel

    var body: some View {
        VStack(spacing: 14) {
            if model.capabilities.hasTorch {
                SliderRow(
                    icon: "bolt.fill",
                    color: .lumaAccent,
                    label: "FLASH",
                    value: Binding(
                        get: { Double(model.torchLevel) },
                        set: { model.setTorchLevel(Float($0)) }
                    ),
                    range: 0.01...1,
                    displayValue: "\(Int((model.torchLevel * 100).rounded()))%"
                )
            }

            let exposure = model.capabilities.exposureRange
            if exposure.upperBound > exposure.lowerBound {
                SliderRow(
                    icon: "plusminus.circle",
                    color: .white,
                    label: "EXPOSURE",
                    value: Binding(
                        get: { Double(model.exposureBias) },
                        set: { model.setExposureBias(Float($0)) }
                    ),
                    range: Double(exposure.lowerBound)...Double(exposure.upperBound),
                    displayValue: String(format: "%+.1f EV", model.exposureBias),
                    onReset: model.exposureBias == 0 ? nil : { model.setExposureBias(0) }
                )
            }

            let zoom = model.capabilities.zoomRange
            if zoom.upperBound > zoom.lowerBound {
                SliderRow(
                    icon: "magnifyingglass",
                    color: .white,
                    label: "ZOOM",
                    value: Binding(
                        get: { Double(model.zoom) },
                        set: { model.setZoom(CGFloat($0)) }
                    ),
                    range: Double(zoom.lowerBound)...Double(zoom.upperBound),
                    displayValue: ZoomDial.label(for: model.zoom) + "×"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .padding(.horizontal, 16)
    }
}

private struct SliderRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let displayValue: String
    var onReset: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.5))
                    if let onReset {
                        Button("RESET", action: onReset)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.lumaAccent)
                    }
                    Spacer()
                    Text(displayValue)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
                Slider(value: value, in: range)
                    .tint(color)
            }
        }
    }
}
