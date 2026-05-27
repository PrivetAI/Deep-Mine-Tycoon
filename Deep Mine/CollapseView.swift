import SwiftUI

struct CollapseView: View {
    @EnvironmentObject var store: DDMStore
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 14) {
                    prestigeCard
                    Text("PERMANENT UPGRADES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(DDMPalette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                    ForEach(DDMGlobalDef.all) { def in
                        GlobalRow(def: def)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Collapse", displayMode: .inline)
        .alert(isPresented: $showConfirm) {
            Alert(
                title: Text("Collapse the Mine?"),
                message: Text("Reset depth, gold, ore and run upgrades to gain \(store.pendingGems) gem\(store.pendingGems == 1 ? "" : "s"). Gems, permanent upgrades and achievements are kept."),
                primaryButton: .destructive(Text("Collapse")) {
                    store.collapse()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var prestigeCard: some View {
        VStack(spacing: 14) {
            DDMGemBadge(size: 56)
            Text("\(store.save.gems) Gems")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Text("Each gem grants +2% global gold & ore yield.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 0) {
                infoCol("Current Mult", String(format: "x%.2f", store.yieldMultiplier))
                divider
                infoCol("Run Depth", DDMFormat.depth(store.save.runMaxDepth))
                divider
                infoCol("Ore Sold", DDMFormat.number(store.save.lifetimeOreSold))
            }
            .padding(.vertical, 6)

            VStack(spacing: 4) {
                Text("Collapse now to gain")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(DDMPalette.textMuted)
                HStack(spacing: 6) {
                    DDMGemBadge(size: 22)
                    Text("\(store.pendingGems)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.gemDeep)
                }
            }

            Button {
                showConfirm = true
            } label: {
                Text(store.canCollapse ? "Collapse Mine" : "Dig deeper to earn gems")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(store.canCollapse ? DDMPalette.accent : DDMPalette.locked)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!store.canCollapse)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .ddmPanel()
    }

    private func infoCol(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(DDMPalette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(DDMPalette.panelDeep).frame(width: 1, height: 28)
    }
}

struct GlobalRow: View {
    @EnvironmentObject var store: DDMStore
    let def: DDMGlobalDef

    var body: some View {
        let level = store.globalLevel(def.kind)
        let maxed = level >= def.maxLevel
        let cost = def.cost(at: level)
        let affordable = store.canBuyGlobal(def.kind)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 46, height: 46)
                DDMGemBadge(size: 28)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textPrimary)
                    Text("Lv \(level)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DDMPalette.gemDeep)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DDMPalette.gem.opacity(0.2)))
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                store.buyGlobal(def.kind)
            } label: {
                VStack(spacing: 1) {
                    if maxed {
                        Text("MAX")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    } else {
                        HStack(spacing: 3) {
                            DDMGemBadge(size: 13)
                            Text("\(cost)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        Text("BUY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 76)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(maxed ? DDMPalette.success : (affordable ? DDMPalette.gemDeep : DDMPalette.locked))
                )
            }
            .buttonStyle(.plain)
            .disabled(maxed || !affordable)
        }
        .padding(14)
        .ddmPanel()
    }
}
