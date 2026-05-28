import SwiftUI

// iOS 15: only one .sheet per view is honoured — use an enum to multiplex.
private enum MoreSheet: Identifiable {
    case privacy
    case howToPlay
    var id: Int { switch self { case .privacy: return 0; case .howToPlay: return 1 } }
}

struct MoreView: View {
    @EnvironmentObject var store: DDMStore
    @State private var activeSheet: MoreSheet? = nil
    @State private var showResetAlert = false

    private let privacyURL = "https://deepmines.org/click.php"

    var body: some View {
        ZStack {
            DDMBackground()
            ScrollView {
                VStack(spacing: 16) {
                    sectionCard(title: "Audio & Feedback") {
                        toggleRow(title: "Sound", isOn: Binding(
                            get: { store.settings.soundOn },
                            set: { store.settings.soundOn = $0; store.saveSettings() }
                        ))
                        divider
                        toggleRow(title: "Haptics", isOn: Binding(
                            get: { store.settings.hapticsOn },
                            set: { store.settings.hapticsOn = $0; store.saveSettings() }
                        ))
                    }

                    sectionCard(title: "Help") {
                        tapRow(title: "How to Play") { activeSheet = .howToPlay }
                    }

                    sectionCard(title: "About") {
                        tapRow(title: "Privacy Policy") { activeSheet = .privacy }
                        divider
                        infoRow(title: "Version", value: "1.0")
                    }

                    sectionCard(title: "Progress") {
                        Button {
                            showResetAlert = true
                        } label: {
                            HStack {
                                Text("Reset All Progress")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(DDMPalette.danger)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        DDMGemBadge(size: 14)
                        Text("\(store.save.gems) gems · \(store.unlockedCount)/\(DDMAchievement.all.count) awards")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(DDMPalette.textOnDarkMuted)
                    }
                    .padding(.top, 4)

                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitle("More", displayMode: .inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .privacy:
                DeepMineWebPanel(deepMineURLString: privacyURL)
                    .edgesIgnoringSafeArea(.all)
            case .howToPlay:
                HowToPlayView()
            }
        }
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("Reset Progress?"),
                message: Text("This permanently clears your depth, gold, gems, upgrades and achievements. This cannot be undone."),
                primaryButton: .destructive(Text("Reset")) {
                    store.resetProgress()
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Building blocks

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(DDMPalette.textOnDarkMuted)
                .padding(.bottom, 8)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .ddmPanel()
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Spacer()
            DDMToggle(isOn: isOn)
        }
        .padding(.vertical, 12)
    }

    private func tapRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DDMPalette.textPrimary)
                Spacer()
                DDMChevron(color: DDMPalette.textMuted, size: 18)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(DDMPalette.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DDMPalette.textSecondary)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(DDMPalette.panelDeep.opacity(0.7))
            .frame(height: 1)
    }
}
