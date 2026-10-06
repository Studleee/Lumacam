import SwiftUI

struct CircleIconButton: View {
    let systemName: String
    var isActive = false
    var size: CGFloat = 44
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.lumaAccent : Color.white.opacity(0.15))
                Image(systemName: systemName)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(isActive ? Color.black : Color.white)
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white))
                        .offset(x: 6, y: -4)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
