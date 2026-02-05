import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanel: NotchPanel?
    private let windowHeight: CGFloat = 500

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupNotchWindow()
        observeScreenChanges()
        startHookServices()
        startUsageService()
        observeSettingsRequest()
    }

    private func startHookServices() {
        HookInstaller.installIfNeeded()
        SocketServer.shared.start { event in
            Task { @MainActor in
                NotchiStateMachine.shared.handleEvent(event)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupNotchWindow() {
        ScreenSelector.shared.refreshScreens()
        guard let screen = ScreenSelector.shared.selectedScreen else { return }
        NotchPanelManager.shared.updateGeometry(for: screen)

        let panel = NotchPanel(frame: windowFrame(for: screen))
        NotchPanelManager.shared.panel = panel

        let contentView = NotchContentView()
        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView
        panel.orderFrontRegardless()

        self.notchPanel = panel
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionWindow),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func repositionWindow() {
        guard let panel = notchPanel else { return }
        ScreenSelector.shared.refreshScreens()
        guard let screen = ScreenSelector.shared.selectedScreen else { return }

        NotchPanelManager.shared.updateGeometry(for: screen)
        panel.setFrame(windowFrame(for: screen), display: true)
    }

    private func windowFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        return NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )
    }

    private func startUsageService() {
        ClaudeUsageService.shared.startPolling()
    }

    private func observeSettingsRequest() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .notchiOpenSettings,
            object: nil
        )
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }
}
