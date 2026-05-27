import SwiftUI

struct AwardsView: View {
    @EnvironmentObject var store: DDMStore

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 16) {
                    statsCard
                    achievementsSection
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("Awards", displayMode: .inline)
        .onAppear { store.checkAchievements() }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STATISTICS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(DDMPalette.textMuted)
                .padding(.bottom, 10)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                statRow("Current Depth", DDMFormat.depth(store.save.depth))
                divider
                statRow("Max Depth", DDMFormat.depth(store.save.maxDepth))
                divider
                statRow("Gold", DDMFormat.number(store.save.gold))
                divider
                statRow("Lifetime Gold", DDMFormat.number(store.save.lifetimeGoldEarned))
                divider
                statRow("Gold / sec", DDMFormat.number(store.goldPerSecond))
                divider
                statRow("Ore Sold (value)", DDMFormat.number(store.save.lifetimeOreSold))
                divider
                statRow("Gems", "\(store.save.gems)")
                divider
                statRow("Collapses", "\(store.save.totalCollapses)")
                divider
                statRow("Total Taps", "\(store.save.totalTaps)")
            }
            .padding(.horizontal, 14)
            .ddmPanel()
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.vertical, 11)
    }

    private var divider: some View {
        Rectangle().fill(DDMPalette.panelDeep.opacity(0.7)).frame(height: 1)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACHIEVEMENTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(DDMPalette.textMuted)
                Spacer()
                Text("\(store.unlockedCount) / \(DDMAchievement.all.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(DDMPalette.accentDeep)
            }
            .padding(.horizontal, 4)

            ForEach(DDMAchievement.all) { ach in
                achievementRow(ach)
            }
        }
    }

    private func achievementRow(_ ach: DDMAchievement) -> some View {
        let result = ach.evaluate(store)
        let done = store.unlockedAchievements.contains(ach.id) || result.done
        return HStack(spacing: 12) {
            DDMMedalShape(color: done ? DDMPalette.amber : DDMPalette.locked, size: 40)
                .opacity(done ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 3) {
                Text(ach.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(done ? DDMPalette.textPrimary : DDMPalette.textMuted)
                Text(ach.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DDMPalette.textSecondary)
                if !done {
                    DDMProgressBar(progress: result.progress, fill: DDMPalette.amber, track: DDMPalette.track, height: 6)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if done {
                DDMCheck(color: DDMPalette.success, size: 20)
            }
        }
        .padding(14)
        .ddmPanel()
    }
}
