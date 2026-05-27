import SwiftUI

/// App shell: a custom HStack tab bar (NOT a TabView) over a `switch` on the selected tab.
/// Each tab hosts its own NavigationView so navigation state is isolated per tab.
struct RootTabView: View {
    @EnvironmentObject var store: DDMStore
    @State private var selectedTab = 0
    @State private var toastTitle: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationView { MineView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { UpgradesView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { CollapseView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 3:
                        NavigationView { AwardsView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { MoreView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }

            if let title = toastTitle {
                unlockToast(title)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(30)
            }

            if let summary = store.offlineSummary {
                DDMOfflineView(summary: summary) {
                    store.dismissOfflineSummary()
                }
                .zIndex(40)
            }
        }
        .onChange(of: store.lastUnlocked) { ids in
            guard let first = ids.first,
                  let ach = DDMAchievement.all.first(where: { $0.id == first }) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                toastTitle = ach.title
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    toastTitle = nil
                }
                store.lastUnlocked = []
            }
        }
    }

    private func unlockToast(_ title: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                DDMMedalShape(color: DDMPalette.amber, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Achievement Unlocked")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(DDMPalette.textMuted)
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(DDMPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DDMPalette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DDMPalette.amber.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Mine", AnyView(DDMTabMineIcon(color: tint(0), size: 24)))
            tabButton(1, "Upgrades", AnyView(DDMTabUpgradeIcon(color: tint(1), size: 22)))
            tabButton(2, "Collapse", AnyView(DDMTabCollapseIcon(color: tint(2), size: 24)))
            tabButton(3, "Awards", AnyView(DDMTabAwardsIcon(color: tint(3), size: 24)))
            tabButton(4, "More", AnyView(DDMTabMoreIcon(color: tint(4), size: 24)))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(DDMPalette.panel.edgesIgnoringSafeArea(.bottom))
        .overlay(
            Rectangle()
                .fill(DDMPalette.panelDeep)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func tint(_ i: Int) -> Color { selectedTab == i ? DDMPalette.accent : DDMPalette.textMuted }

    private func tabButton(_ i: Int, _ label: String, _ icon: AnyView) -> some View {
        Button {
            selectedTab = i
        } label: {
            VStack(spacing: 3) {
                icon
                    .frame(height: 26)
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(tint(i))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// Offline earnings summary overlay.
struct DDMOfflineView: View {
    let summary: DDMOfflineSummary
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("While You Were Away")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(DDMPalette.textPrimary)
                Text(DDMFormat.duration(summary.seconds) + (summary.capped ? " (capped)" : ""))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(DDMPalette.textMuted)

                VStack(spacing: 10) {
                    row(DDMPalette.gold, "Gold earned", DDMFormat.number(summary.gold))
                    row(DDMPalette.amber, "Ore mined", DDMFormat.number(summary.ore))
                    row(DDMPalette.gem, "Depth gained", "\(summary.depth) m")
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DDMPalette.panelRaised)
                )

                Button(action: onDismiss) {
                    Text("Collect")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DDMPalette.accent)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .ddmPanel(corner: 22)
            .padding(.horizontal, 28)
        }
    }

    private func row(_ c: Color, _ label: String, _ value: String) -> some View {
        HStack {
            Circle().fill(c).frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
        }
    }
}
