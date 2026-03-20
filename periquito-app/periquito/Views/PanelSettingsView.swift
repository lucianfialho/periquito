import ServiceManagement
import SwiftUI

struct PanelSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hooksInstalled = HookInstaller.isInstalled()
    @State private var hooksError = false
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var claudeAvailable = false
    @State private var currentFontSize = AppSettings.fontSize

    private var hookStatusText: String {
        if hooksError { return "Error" }
        if hooksInstalled { return "Installed" }
        return "Not Installed"
    }

    private var hookStatusColor: Color {
        hooksInstalled && !hooksError ? TerminalColors.green : TerminalColors.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    displaySection
                    Divider().background(Color.white.opacity(0.08))
                    togglesSection
                    Divider().background(Color.white.opacity(0.08))
                    actionsSection
                }
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)

            Spacer()

            quitSection
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenPickerRow(screenSelector: ScreenSelector.shared)

            SoundPickerView()

            FontSizePickerRow(selected: $currentFontSize)
        }
    }

    private var systemReady: Bool {
        hooksInstalled && !hooksError && claudeAvailable
    }

    @State private var setupExpanded = false

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: toggleLaunchAtLogin) {
                SettingsRowView(icon: "power", title: "Launch at Login") {
                    ToggleSwitch(isOn: launchAtLogin)
                }
            }
            .buttonStyle(.plain)

            if systemReady && !setupExpanded {
                Button(action: { setupExpanded = true }) {
                    SettingsRowView(icon: "checkmark.circle", title: "System") {
                        Text("Ready")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(TerminalColors.green)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: installHooksIfNeeded) {
                    SettingsRowView(icon: "terminal", title: "Hooks") {
                        statusBadge(hookStatusText, color: hookStatusColor)
                    }
                }
                .buttonStyle(.plain)

                SettingsRowView(icon: "textformat.abc", title: "English Analysis") {
                    statusBadge(
                        claudeAvailable ? "Active" : "Claude CLI not found",
                        color: claudeAvailable ? TerminalColors.green : TerminalColors.red
                    )
                }
            }
        }
        .onAppear { checkClaudeCLI() }
    }

    private func checkClaudeCLI() {
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.claude/local/claude"
        ]
        claudeAvailable = candidates.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { updateManager.checkForUpdates() }) {
                SettingsRowView(icon: "arrow.triangle.2.circlepath", title: "Check for Updates") {
                    updateStatusView
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var quitSection: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            Text("Quit Periquito")
                .font(.system(size: currentFontSize.settingsFont - 1))
                .foregroundColor(TerminalColors.dimmedText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    private func connectUsage() {
        ClaudeUsageService.shared.connectAndStartPolling()
    }

    private func installHooksIfNeeded() {
        guard !hooksInstalled else { return }
        hooksError = false
        let success = HookInstaller.installIfNeeded()
        if success {
            hooksInstalled = HookInstaller.isInstalled()
        } else {
            hooksError = true
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: currentFontSize.settingsFont - 2, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateManager.state {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking...")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .upToDate:
            statusBadge("Up to date", color: TerminalColors.green)
        case .found(let version, _):
            statusBadge("v\(version) available", color: TerminalColors.amber)
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 40)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .extracting:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Installing...")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .readyToInstall(let version):
            Button(action: { updateManager.downloadAndInstall() }) {
                statusBadge("Install v\(version)", color: TerminalColors.green)
            }
            .buttonStyle(.plain)
        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Installing...")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .error(let message):
            statusBadge(message, color: TerminalColors.red)
        case .idle:
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundColor(TerminalColors.dimmedText)
        }
    }
}

struct SettingsRowView<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    private var fs: CGFloat { AppSettings.fontSize.settingsFont }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: fs))
                .foregroundColor(TerminalColors.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: fs))
                .foregroundColor(TerminalColors.primaryText)

            Spacer()

            trailing()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ToggleSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? TerminalColors.green : Color.white.opacity(0.15))
                .frame(width: 32, height: 18)

            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .padding(2)
        }
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

struct FontSizePickerRow: View {
    @Binding var selected: AppSettings.FontSize

    var body: some View {
        SettingsRowView(icon: "textformat.size", title: "Font Size") {
            HStack(spacing: 4) {
                ForEach(AppSettings.FontSize.allCases, id: \.rawValue) { size in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = size
                            AppSettings.fontSize = size
                        }
                    }) {
                        Text(size.label)
                            .font(.system(size: 11, weight: selected == size ? .bold : .regular))
                            .foregroundColor(selected == size ? TerminalColors.primaryText : TerminalColors.dimmedText)
                            .frame(width: 28, height: 22)
                            .background(selected == size ? Color.white.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    PanelSettingsView()
        .frame(width: 402, height: 400)
        .background(Color.black)
}
