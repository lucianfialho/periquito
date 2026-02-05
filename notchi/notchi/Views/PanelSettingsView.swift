import SwiftUI

struct PanelSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    displaySection
                    Divider().background(Color.white.opacity(0.08))
                    togglesSection
                    Divider().background(Color.white.opacity(0.08))
                    actionsSection
                    Divider().background(Color.white.opacity(0.08))
                    quitSection
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(TerminalColors.dimmedText)

            ScreenPickerRow(screenSelector: ScreenSelector.shared)

            SoundPickerView()
        }
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowView(
                icon: "power",
                title: "Launch at Login",
                trailing: AnyView(toggleIndicator(false))
            )

            SettingsRowView(
                icon: "terminal",
                title: "Hooks",
                trailing: AnyView(statusBadge("Installed", color: TerminalColors.green))
            )

            SettingsRowView(
                icon: "lock.shield",
                title: "Accessibility",
                trailing: AnyView(statusBadge("Granted", color: TerminalColors.green))
            )
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowView(
                icon: "arrow.triangle.2.circlepath",
                title: "Check for Updates",
                trailing: AnyView(versionText)
            )

            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://github.com/sk-ruban/notchi")!)
            }) {
                SettingsRowView(
                    icon: "star",
                    title: "Star on GitHub",
                    trailing: AnyView(Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.dimmedText))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var quitSection: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 13))
                Text("Quit Notchi")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(TerminalColors.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(TerminalColors.red.opacity(0.1))
            .contentShape(Rectangle())
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private func toggleIndicator(_ isOn: Bool) -> some View {
        Circle()
            .fill(isOn ? TerminalColors.green : TerminalColors.dimmedText)
            .frame(width: 8, height: 8)
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    private var versionText: some View {
        Text("v1.0.0")
            .font(.system(size: 10))
            .foregroundColor(TerminalColors.dimmedText)
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let trailing: AnyView

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.primaryText)

            Spacer()

            trailing
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    PanelSettingsView()
        .frame(width: 402, height: 400)
        .background(Color.black)
}
