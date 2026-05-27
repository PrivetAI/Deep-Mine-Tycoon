import SwiftUI

struct HowToPlayView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            DDMBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        step(icon: AnyView(DDMPickaxeShape(color: DDMPalette.accentDeep, handle: DDMPalette.dirt, size: 30)),
                             title: "Tap to Dig",
                             body: "Tap the rock face to swing your pickaxe. Each tap chips away the block's HP. Clear it to drop ore and descend one meter deeper.")
                        step(icon: AnyView(DDMOreChunk(color: DDMPalette.gold, size: 30)),
                             title: "Collect & Sell Ore",
                             body: "Blocks may hold ore veins — coal, copper, iron, gold, gems and rarer ores the deeper you go. Sell ore for gold from the Mine screen.")
                        step(icon: AnyView(DDMTabUpgradeIcon(color: DDMPalette.gemDeep, size: 28)),
                             title: "Buy Upgrades",
                             body: "Spend gold on Pickaxe Power for bigger taps, Drill Rigs for automatic digging, Mine Carts for auto-selling, and Ore Graders to raise sell value.")
                        step(icon: AnyView(DDMGemBadge(size: 28)),
                             title: "Collapse for Gems",
                             body: "When you've dug deep, Collapse the mine to convert your progress into Gems. Each gem permanently boosts all future yield. Spend gems on permanent upgrades.")
                        step(icon: AnyView(DDMChevron(color: DDMPalette.accentDeep, size: 28).rotationEffect(.degrees(90))),
                             title: "Dig Deeper",
                             body: "Deeper rock is tougher but holds richer ore. Build up auto-drills so the mine keeps working even while you're away — collect your offline earnings when you return.")
                        step(icon: AnyView(DDMMedalShape(color: DDMPalette.amber, size: 30)),
                             title: "Earn Awards",
                             body: "Hit depth, gold, ore and collapse milestones to unlock achievements in the Awards tab.")
                        Color.clear.frame(height: 20)
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("How to Play")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textOnDark)
            Spacer()
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DDMPalette.amber)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func step(icon: AnyView, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DDMPalette.panelRaised)
                    .frame(width: 50, height: 50)
                icon
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(DDMPalette.textPrimary)
                Text(body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .ddmPanel()
    }
}
