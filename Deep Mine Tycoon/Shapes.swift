import SwiftUI

// All icons / art are custom SwiftUI Shapes — no SF Symbols, no emoji, no system images.

// MARK: - Tab icons

struct DDMTabMineIcon: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        // pickaxe head + handle (abstract crossed mark)
        ZStack {
            // handle
            Capsule()
                .fill(color)
                .frame(width: size * 0.10, height: size * 0.86)
                .rotationEffect(.degrees(40))
            // head arc
            Path { p in
                let s = size
                p.move(to: CGPoint(x: s * 0.16, y: s * 0.30))
                p.addQuadCurve(to: CGPoint(x: s * 0.84, y: s * 0.30),
                               control: CGPoint(x: s * 0.5, y: s * 0.02))
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct DDMTabUpgradeIcon: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        // ascending bars
        HStack(alignment: .bottom, spacing: size * 0.10) {
            barFill(0.45)
            barFill(0.70)
            barFill(1.0)
        }
        .frame(width: size, height: size)
    }
    private func barFill(_ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
            .fill(color)
            .frame(width: size * 0.20, height: size * h)
    }
}

struct DDMTabCollapseIcon: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        // gem / diamond facet
        DDMGemShape()
            .fill(color)
            .frame(width: size * 0.82, height: size * 0.82)
    }
}

struct DDMTabAwardsIcon: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: size * 0.10)
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(y: -size * 0.12)
            // ribbon
            Path { p in
                let s = size
                p.move(to: CGPoint(x: s * 0.38, y: s * 0.55))
                p.addLine(to: CGPoint(x: s * 0.30, y: s * 0.92))
                p.addLine(to: CGPoint(x: s * 0.5, y: s * 0.78))
                p.addLine(to: CGPoint(x: s * 0.70, y: s * 0.92))
                p.addLine(to: CGPoint(x: s * 0.62, y: s * 0.55))
                p.closeSubpath()
            }
            .fill(color)
        }
        .frame(width: size, height: size)
    }
}

struct DDMTabMoreIcon: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        HStack(spacing: size * 0.16) {
            dot
            dot
            dot
        }
        .frame(width: size, height: size)
    }
    private var dot: some View {
        Circle().fill(color).frame(width: size * 0.18, height: size * 0.18)
    }
}

// MARK: - Gem shape

struct DDMGemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let topY = h * 0.28
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w, y: topY))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: 0, y: topY))
        p.closeSubpath()
        return p
    }
}

struct DDMGemBadge: View {
    var size: CGFloat
    var body: some View {
        ZStack {
            DDMGemShape()
                .fill(
                    LinearGradient(colors: [DDMPalette.gemLight, DDMPalette.gem, DDMPalette.gemDeep],
                                   startPoint: .top, endPoint: .bottom)
                )
            DDMGemShape()
                .stroke(DDMPalette.gemDeep, lineWidth: size * 0.04)
            // facet line
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: 0))
                p.addLine(to: CGPoint(x: size * 0.5, y: size))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Ore chunk shape (rounded rock with embedded sparkle)

struct DDMOreChunk: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        ZStack {
            // rock body — irregular rounded polygon
            DDMRockShape()
                .fill(color)
            DDMRockShape()
                .stroke(Color.black.opacity(0.18), lineWidth: size * 0.03)
            // highlight sparkle
            Path { p in
                let c = CGPoint(x: size * 0.40, y: size * 0.36)
                let r = size * 0.10
                p.move(to: CGPoint(x: c.x, y: c.y - r))
                p.addLine(to: CGPoint(x: c.x + r * 0.4, y: c.y))
                p.addLine(to: CGPoint(x: c.x, y: c.y + r))
                p.addLine(to: CGPoint(x: c.x - r * 0.4, y: c.y))
                p.closeSubpath()
            }
            .fill(Color.white.opacity(0.7))
        }
        .frame(width: size, height: size)
    }
}

struct DDMRockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.22, y: h * 0.12))
        p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.90))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.94))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.50))
        p.closeSubpath()
        return p
    }
}

// MARK: - Gold coin (for gold balance)

struct DDMCoinShape: View {
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [DDMPalette.goldLight, DDMPalette.gold, DDMPalette.goldDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Circle()
                .stroke(DDMPalette.goldDeep, lineWidth: size * 0.06)
                .frame(width: size * 0.74, height: size * 0.74)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pickaxe mark (used in loading / headers)

struct DDMPickaxeShape: View {
    var color: Color
    var handle: Color
    var size: CGFloat
    var body: some View {
        ZStack {
            // handle
            Capsule()
                .fill(handle)
                .frame(width: size * 0.10, height: size * 0.80)
                .rotationEffect(.degrees(45))
            // head
            Path { p in
                let s = size
                p.move(to: CGPoint(x: s * 0.12, y: s * 0.34))
                p.addQuadCurve(to: CGPoint(x: s * 0.88, y: s * 0.34),
                               control: CGPoint(x: s * 0.5, y: -s * 0.02))
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Chevron

struct DDMChevron: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: size * 0.38, y: size * 0.26))
            p.addLine(to: CGPoint(x: size * 0.64, y: size * 0.5))
            p.addLine(to: CGPoint(x: size * 0.38, y: size * 0.74))
        }
        .stroke(color, style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

// MARK: - Star

struct DDMStar: View {
    var filled: Bool
    var size: CGFloat
    var body: some View {
        DDMStarShape()
            .fill(filled ? DDMPalette.gold : DDMPalette.track)
            .frame(width: size, height: size)
    }
}

struct DDMStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let angle = (Double(i) * 36.0 - 90.0) * .pi / 180.0
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r,
                             y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Medal (achievements)

struct DDMMedalShape: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [color.opacity(0.9), color],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: size * 0.04)
                .frame(width: size * 0.60, height: size * 0.60)
            DDMStarShape()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.34, height: size * 0.34)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Lamp glow (loading)

struct DDMLampShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // lantern body
        p.move(to: CGPoint(x: w * 0.32, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.78))
        p.closeSubpath()
        return p
    }
}

// MARK: - Toggle (themed)

struct DDMToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? DDMPalette.success : DDMPalette.track)
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checkmark

struct DDMCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.76))
        p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.24))
        return p
    }
}

struct DDMCheck: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        DDMCheckShape()
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

// MARK: - Progress bar

struct DDMProgressBar: View {
    var progress: Double // 0...1
    var fill: Color = DDMPalette.amber
    var track: Color = DDMPalette.track
    var height: CGFloat = 10
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
