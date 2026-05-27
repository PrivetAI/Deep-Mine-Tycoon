import SwiftUI

// Underground mine palette — earthy browns, amber lamp glow, rock greys, gold-ore highlights, cream UI panels.
enum DDMPalette {
    // Backgrounds — deep cavern tones
    static let background = Color(red: 0.16, green: 0.12, blue: 0.09)       // dark earth
    static let backgroundDeep = Color(red: 0.10, green: 0.07, blue: 0.05)  // deepest dark
    static let cavern = Color(red: 0.21, green: 0.16, blue: 0.12)          // cavern brown

    // Cream UI panels
    static let panel = Color(red: 0.96, green: 0.93, blue: 0.86)           // cream panel
    static let panelRaised = Color(red: 0.91, green: 0.86, blue: 0.76)     // raised cream
    static let panelDeep = Color(red: 0.86, green: 0.79, blue: 0.66)       // deeper cream edge

    // Rock strata
    static let rock = Color(red: 0.40, green: 0.36, blue: 0.33)            // rock grey
    static let rockDark = Color(red: 0.30, green: 0.27, blue: 0.24)
    static let rockLight = Color(red: 0.52, green: 0.47, blue: 0.43)
    static let dirt = Color(red: 0.45, green: 0.32, blue: 0.21)            // earthy brown
    static let dirtDark = Color(red: 0.33, green: 0.23, blue: 0.15)
    static let dirtLight = Color(red: 0.57, green: 0.42, blue: 0.28)

    // Amber lamp glow
    static let amber = Color(red: 0.98, green: 0.69, blue: 0.22)
    static let amberDeep = Color(red: 0.86, green: 0.52, blue: 0.12)
    static let amberGlow = Color(red: 1.0, green: 0.82, blue: 0.42)

    // Gold ore
    static let gold = Color(red: 0.95, green: 0.74, blue: 0.24)
    static let goldDeep = Color(red: 0.78, green: 0.56, blue: 0.10)
    static let goldLight = Color(red: 1.0, green: 0.88, blue: 0.52)

    // Gems (prestige)
    static let gem = Color(red: 0.40, green: 0.78, blue: 0.86)
    static let gemDeep = Color(red: 0.22, green: 0.58, blue: 0.70)
    static let gemLight = Color(red: 0.62, green: 0.90, blue: 0.96)

    // Accent (warm amber, used for highlights / selected tabs)
    static let accent = Color(red: 0.92, green: 0.55, blue: 0.16)
    static let accentDeep = Color(red: 0.78, green: 0.42, blue: 0.10)

    // Text on cream panels (dark)
    static let textPrimary = Color(red: 0.18, green: 0.13, blue: 0.09)
    static let textSecondary = Color(red: 0.40, green: 0.33, blue: 0.27)
    static let textMuted = Color(red: 0.56, green: 0.49, blue: 0.42)

    // Text on dark backgrounds (light)
    static let textOnDark = Color(red: 0.96, green: 0.92, blue: 0.84)
    static let textOnDarkMuted = Color(red: 0.74, green: 0.66, blue: 0.56)

    static let success = Color(red: 0.36, green: 0.70, blue: 0.42)
    static let danger = Color(red: 0.80, green: 0.32, blue: 0.24)
    static let locked = Color(red: 0.62, green: 0.56, blue: 0.49)
    static let track = Color(red: 0.82, green: 0.76, blue: 0.66)
}

enum DDMMetrics {
    static let corner: CGFloat = 16
    static let cornerSmall: CGFloat = 10
}

// Reusable raised cream panel background.
struct DDMPanelModifier: ViewModifier {
    var corner: CGFloat = DDMMetrics.corner
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(DDMPalette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(DDMPalette.panelDeep, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func ddmPanel(corner: CGFloat = DDMMetrics.corner) -> some View {
        modifier(DDMPanelModifier(corner: corner))
    }
}

// Background gradient used across screens — deep cavern.
struct DDMBackground: View {
    var body: some View {
        LinearGradient(
            colors: [DDMPalette.background, DDMPalette.backgroundDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
