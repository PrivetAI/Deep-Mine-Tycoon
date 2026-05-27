import SwiftUI

struct MineView: View {
    @EnvironmentObject var store: DDMStore
    @State private var tapBounce = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DDMBackground()
                VStack(spacing: 0) {
                    topBar
                    digFace(screenSize: geo.size)
                    bottomPanel
                }
            }
        }
        .navigationBarTitle("Mine", displayMode: .inline)
        .onAppear { store.checkAchievements() }
    }

    // MARK: - Top bar (gold + depth + gems)

    private var topBar: some View {
        HStack(spacing: 12) {
            statChip(icon: AnyView(DDMCoinShape(size: 22)),
                     value: DDMFormat.number(store.save.gold),
                     label: "Gold")
            statChip(icon: AnyView(DDMGemBadge(size: 20)),
                     value: "\(store.save.gems)",
                     label: "Gems")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func statChip(icon: AnyView, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            icon.frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(DDMPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(DDMPalette.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .ddmPanel(corner: 14)
    }

    // MARK: - Dig face (strata view) — tap target

    private func digFace(screenSize: CGSize) -> some View {
        let block = store.currentBlock
        let hpFrac = block.maxHP > 0 ? max(0, min(1, block.hp / block.maxHP)) : 0
        return ZStack {
            // strata canvas — pass parent size explicitly
            DDMStrataView(depth: store.save.depth, screenSize: screenSize)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack {
                // depth banner
                HStack {
                    Text(DDMFormat.depth(store.save.depth))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textOnDark)
                    Spacer()
                    Text("Max " + DDMFormat.depth(store.save.maxDepth))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(DDMPalette.textOnDarkMuted)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                Spacer()

                // current block face with HP
                blockFace(block: block, hpFrac: hpFrac)
                    .scaleEffect(tapBounce ? 0.95 : 1.0)

                Spacer()

                // floating hits
                ZStack {
                    ForEach(store.floatingHits) { hit in
                        Text(hit.text)
                            .font(.system(size: hit.crit ? 22 : 16, weight: .heavy, design: .rounded))
                            .foregroundColor(hit.crit ? DDMPalette.amberGlow : DDMPalette.goldLight)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(height: 30)
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.08)) { tapBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeIn(duration: 0.08)) { tapBounce = false }
            }
            store.tapDig()
        }
    }

    private func blockFace(block: DDMBlock, hpFrac: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                // the rock block
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(colors: [DDMPalette.rockLight, DDMPalette.rock, DDMPalette.rockDark],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 150, height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DDMPalette.rockDark, lineWidth: 3)
                    )
                // crack overlay as HP drops
                DDMCracksShape(intensity: 1 - hpFrac)
                    .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 150, height: 150)
                // ore vein
                if let ore = block.oreType {
                    DDMOreChunk(color: ore.color, size: 64)
                }
            }
            // HP bar
            VStack(spacing: 4) {
                DDMProgressBar(progress: hpFrac, fill: DDMPalette.amber, track: DDMPalette.rockDark, height: 10)
                    .frame(width: 180)
                Text("\(DDMFormat.number(block.hp)) / \(DDMFormat.number(block.maxHP)) HP")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(DDMPalette.textOnDarkMuted)
            }
        }
    }

    // MARK: - Bottom panel (ore inventory + sell + tap stat)

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            // tap / dps row
            HStack(spacing: 10) {
                miniStat("Tap", DDMFormat.number(store.tapDamage), DDMPalette.accent)
                miniStat("Auto/s", DDMFormat.number(store.autoDPS), DDMPalette.gem)
                miniStat("Gold/s", DDMFormat.number(store.goldPerSecond), DDMPalette.gold)
            }
            .padding(.horizontal, 16)

            // ore inventory
            oreInventory

            // sell button
            Button {
                store.sellAll()
            } label: {
                HStack {
                    DDMCoinShape(size: 20)
                    Text("Sell All Ore")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text(store.totalHeldOre > 0 ? "+\(DDMFormat.number(store.heldOreValue))" : "—")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(store.totalHeldOre > 0 ? DDMPalette.accent : DDMPalette.locked)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.totalHeldOre <= 0)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(DDMPalette.cavern.edgesIgnoringSafeArea(.bottom))
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textOnDark)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DDMPalette.background.opacity(0.6))
        )
    }

    private var oreInventory: some View {
        let held = DDMOre.allCases.filter { (store.save.oreCounts[$0.rawValue] ?? 0) > 0 }
        return Group {
            if held.isEmpty {
                Text("Dig to collect ore…")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textOnDarkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(held, id: \.rawValue) { ore in
                            oreCell(ore)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func oreCell(_ ore: DDMOre) -> some View {
        let count = store.save.oreCounts[ore.rawValue] ?? 0
        return VStack(spacing: 3) {
            DDMOreChunk(color: ore.color, size: 28)
            Text(DDMFormat.number(count))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(DDMPalette.textOnDark)
            Text(ore.name)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(DDMPalette.textOnDarkMuted)
                .lineLimit(1)
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DDMPalette.background.opacity(0.55))
        )
    }
}

// MARK: - Strata background (Canvas) — depth-aware layered rock

struct DDMStrataView: View {
    let depth: Int
    let screenSize: CGSize

    var body: some View {
        // Use parent-passed screenSize for camera math, not the Canvas's own size.
        Canvas { context, _ in
            let w = screenSize.width
            let h = max(220, screenSize.height * 0.5)
            let rect = CGRect(x: 0, y: 0, width: w, height: h)

            // base fill
            context.fill(Path(rect), with: .color(DDMPalette.dirtDark))

            // horizontal strata bands scrolling with depth
            let bandHeight: CGFloat = 46
            let scroll = CGFloat(depth) * 6.0
            let offset = scroll.truncatingRemainder(dividingBy: bandHeight)
            var y = -offset - bandHeight
            var idx = Int(scroll / bandHeight)
            while y < h + bandHeight {
                let band = CGRect(x: 0, y: y, width: w, height: bandHeight)
                let shade = idx % 2 == 0 ? DDMPalette.dirt : DDMPalette.dirtDark
                context.fill(Path(band), with: .color(shade))

                // speckle pebbles seeded by band index — deterministic
                var rng = DDMRandom(seed: ddmSeed(idx, 0x57A))
                let pebbles = 5
                for _ in 0..<pebbles {
                    let px = rng.nextDouble() * Double(w)
                    let py = Double(y) + rng.nextDouble() * Double(bandHeight)
                    let r = 2.0 + rng.nextDouble() * 4.0
                    let pebRect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
                    let pebColor = rng.chance(0.3) ? DDMPalette.rockLight : DDMPalette.rockDark
                    context.fill(Path(ellipseIn: pebRect), with: .color(pebColor.opacity(0.5)))
                }
                y += bandHeight
                idx += 1
            }

            // amber lamp glow at top
            let glowRect = CGRect(x: w * 0.5 - 80, y: -40, width: 160, height: 120)
            context.fill(Path(ellipseIn: glowRect), with: .color(DDMPalette.amberGlow.opacity(0.10)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DDMPalette.dirtDark)
    }
}

// MARK: - Cracks overlay (grows with damage)

struct DDMCracksShape: Shape {
    var intensity: Double // 0...1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let i = max(0, min(1, intensity))
        guard i > 0.12 else { return p }
        let w = rect.width, h = rect.height
        // main crack
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.4))
        p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.6))
        p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.9))
        if i > 0.4 {
            p.move(to: CGPoint(x: w * 0.42, y: h * 0.4))
            p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.5))
            p.move(to: CGPoint(x: w * 0.55, y: h * 0.6))
            p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.68))
        }
        if i > 0.7 {
            p.move(to: CGPoint(x: w * 0.48, y: h * 0.9))
            p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.95))
            p.move(to: CGPoint(x: w * 0.2, y: h * 0.5))
            p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.75))
        }
        return p
    }
}
