import SwiftUI

struct UpgradesView: View {
    @EnvironmentObject var store: DDMStore

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 14) {
                    goldHeader
                    ForEach(DDMUpgradeDef.all) { def in
                        UpgradeRow(def: def)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Upgrades", displayMode: .inline)
    }

    private var goldHeader: some View {
        HStack(spacing: 10) {
            DDMCoinShape(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(DDMFormat.number(store.save.gold))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(DDMPalette.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("AVAILABLE GOLD")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(DDMPalette.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(DDMFormat.number(store.autoDPS))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(DDMPalette.gemDeep)
                Text("AUTO DMG/S")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(DDMPalette.textMuted)
            }
        }
        .padding(16)
        .ddmPanel()
    }
}

struct UpgradeRow: View {
    @EnvironmentObject var store: DDMStore
    let def: DDMUpgradeDef

    var body: some View {
        let level = store.upgradeLevel(def.kind)
        let cost = def.cost(at: level)
        let affordable = store.canBuy(def.kind)
        return HStack(spacing: 12) {
            iconBadge
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textPrimary)
                    Text("Lv \(level)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(DDMPalette.accentDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(DDMPalette.amber.opacity(0.18))
                        )
                }
                Text(def.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(effectText(level: level))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(DDMPalette.gemDeep)
            }
            Spacer(minLength: 4)
            Button {
                store.buy(def.kind)
            } label: {
                VStack(spacing: 1) {
                    Text(DDMFormat.number(cost))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("BUY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundColor(.white)
                .frame(width: 78)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(affordable ? DDMPalette.accent : DDMPalette.locked)
                )
            }
            .buttonStyle(.plain)
            .disabled(!affordable)
        }
        .padding(14)
        .ddmPanel()
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DDMPalette.panelRaised)
                .frame(width: 48, height: 48)
            upgradeIcon
        }
    }

    @ViewBuilder private var upgradeIcon: some View {
        switch def.kind {
        case .pickaxe:
            DDMPickaxeShape(color: DDMPalette.accentDeep, handle: DDMPalette.dirt, size: 30)
        case .drillCount, .drillSpeed:
            DDMTabUpgradeIcon(color: DDMPalette.gemDeep, size: 26)
        case .oreValue, .refiner:
            DDMCoinShape(size: 28)
        case .cart:
            DDMOreChunk(color: DDMPalette.amberDeep, size: 26)
        case .elevator:
            DDMChevron(color: DDMPalette.accentDeep, size: 26)
                .rotationEffect(.degrees(90))
        }
    }

    private func effectText(level: Int) -> String {
        switch def.kind {
        case .pickaxe:
            return "Tap damage: \(DDMFormat.number(store.tapDamage))"
        case .drillCount:
            return "Drills: \(level + store.globalLevel(.autoStart))"
        case .drillSpeed:
            return "Auto dmg/s: \(DDMFormat.number(store.autoDPS))"
        case .oreValue:
            return "Sell value x\(String(format: "%.2f", store.oreValueMultiplier))"
        case .cart:
            return level > 0 ? "Auto-sell: \(DDMFormat.number(store.cartRate))/s" : "Manual selling only"
        case .elevator:
            return "Depth/clear: +\(store.elevatorBonus) m"
        case .refiner:
            return "Refining bonus active"
        }
    }
}
