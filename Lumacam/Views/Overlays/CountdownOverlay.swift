import SwiftUI

struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 140, weight: .thin, design: .rounded))
            .foregroundStyle(Color.white)
            .shadow(color: .black.opacity(0.5), radius: 12)
            .contentTransition(.numericText(countsDown: true))
            .animation(.easeInOut(duration: 0.3), value: value)
            .allowsHitTesting(false)
    }
}
