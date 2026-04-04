import SwiftUI

@MainActor
struct PanelSettingsView: View {
    @Bindable var viewModel: PanelSettingsViewModel

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    displaySection(selectedFontSize: $bindableViewModel.currentFontSize)
                    Divider().background(Color.white.opacity(0.08))
                    togglesSection
                    Divider().background(Color.white.opacity(0.08))
                    actionsSection
                }
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)

            Spacer()

            Button(action: viewModel.quitApplication) {
                Text("Quit Periquito")
                    .font(.system(size: viewModel.currentFontSize.settingsFont - 1))
                    .foregroundColor(TerminalColors.dimmedText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: viewModel.onAppear)
    }

    private func displaySection(selectedFontSize: Binding<AppSettings.FontSize>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenPickerRow(screenSelector: viewModel.screenSelector)
            SoundPickerView()
            FontSizePickerRow(selected: selectedFontSize)
        }
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: viewModel.toggleLaunchAtLogin) {
                SettingsRowView(icon: "power", title: "Launch at Login") {
                    ToggleSwitch(isOn: viewModel.launchAtLogin)
                }
            }
            .buttonStyle(.plain)

            if viewModel.systemReady && !viewModel.setupExpanded {
                Button(action: { viewModel.setupExpanded = true }) {
                    SettingsRowView(icon: "checkmark.circle", title: "System") {
                        Text("Ready")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(TerminalColors.green)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: viewModel.installHooksIfNeeded) {
                    SettingsRowView(icon: "terminal", title: "Hooks") {
                        statusBadge(viewModel.hookStatusText, color: viewModel.hookStatusColor)
                    }
                }
                .buttonStyle(.plain)

                SettingsRowView(icon: "textformat.abc", title: "English Analysis") {
                    statusBadge(
                        viewModel.claudeAvailable ? "Active" : "Claude CLI not found",
                        color: viewModel.claudeAvailable ? TerminalColors.green : TerminalColors.red
                    )
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: viewModel.checkForUpdates) {
                SettingsRowView(icon: "arrow.triangle.2.circlepath", title: "Check for Updates") {
                    updateStatusView
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: viewModel.currentFontSize.settingsFont - 2, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch viewModel.updateState {
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
            Button(action: viewModel.downloadAndInstall) {
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
            Text("v\(viewModel.appVersion)")
                .font(.system(size: 10))
                .foregroundColor(TerminalColors.dimmedText)
        }
    }
}

#Preview {
    PanelSettingsView(viewModel: PanelSettingsViewModel())
        .frame(width: 402, height: 400)
        .background(Color.black)
}
