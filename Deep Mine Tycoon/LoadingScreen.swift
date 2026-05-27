import SwiftUI

// Splash shown while the launch check runs.
struct DeepMineLoadingScreen: View {
    @State private var swing = false
    @State private var glow = false

    var body: some View {
        ZStack {
            DDMBackground()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(DDMPalette.amberGlow.opacity(glow ? 0.30 : 0.12))
                        .frame(width: 150, height: 150)
                        .blur(radius: 12)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(DDMPalette.cavern)
                        .frame(width: 132, height: 132)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(DDMPalette.dirtDark, lineWidth: 1.5)
                        )
                    DDMPickaxeShape(color: DDMPalette.amber, handle: DDMPalette.dirtLight, size: 88)
                        .rotationEffect(.degrees(swing ? 18 : -18), anchor: .bottomLeading)
                }
                Text("DEEP MINE TYCOON")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(DDMPalette.textOnDark)
                Text("Lighting the lanterns…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textOnDarkMuted)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { swing = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
