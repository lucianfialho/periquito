import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class PanelSettingsViewModel {
    let screenSelector: ScreenSelector

    private let updateManager: UpdateManager
    private let claudeLocator: any ClaudeExecutableLocating

    @ObservationIgnored
    private var updateStateCancellable: AnyCancellable?

    var launchAtLogin = SMAppService.mainApp.status == .enabled
    var hooksInstalled = HookInstaller.isInstalled()
    var hooksError = false
    var claudeAvailable = false
    var currentFontSize = AppSettings.fontSize
    var setupExpanded = false
    var updateState: UpdateState

    init(
        screenSelector: ScreenSelector? = nil,
        updateManager: UpdateManager? = nil,
        claudeLocator: (any ClaudeExecutableLocating)? = nil
    ) {
        let updateManager = updateManager ?? .shared
        self.screenSelector = screenSelector ?? .shared
        self.updateManager = updateManager
        self.claudeLocator = claudeLocator ?? ClaudeExecutableLocator()
        updateState = updateManager.state

        updateStateCancellable = updateManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateState = state
            }
    }

    var hookStatusText: String {
        if hooksError {
            return "Error"
        }

        if hooksInstalled {
            return "Installed"
        }

        return "Not Installed"
    }

    var hookStatusColor: Color {
        hooksInstalled && !hooksError ? TerminalColors.green : TerminalColors.red
    }

    var systemReady: Bool {
        hooksInstalled && !hooksError && claudeAvailable
    }

    var appVersion: String {
        Bundle.main.appVersion
    }

    func onAppear() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        hooksInstalled = HookInstaller.isInstalled()
        claudeAvailable = claudeLocator.locateClaudeExecutable() != nil
    }

    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }

            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            hooksError = true
        }
    }

    func installHooksIfNeeded() {
        guard !hooksInstalled else {
            return
        }

        hooksError = false
        let success = HookInstaller.installIfNeeded()
        hooksInstalled = HookInstaller.isInstalled()
        hooksError = !success
    }

    func checkForUpdates() {
        updateManager.checkForUpdates()
    }

    func downloadAndInstall() {
        updateManager.downloadAndInstall()
    }

    func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
