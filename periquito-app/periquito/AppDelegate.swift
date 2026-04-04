import AppKit
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let updater: SPUUpdater
    private let userDriver: NotchUserDriver
    private let windowController: NotchWindowController
    private let isRunningTests: Bool
    private var bootstrapper: AppBootstrapper?
    private var updaterStarted = false

    override init() {
        isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        userDriver = NotchUserDriver()
        windowController = NotchWindowController()
        updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: nil
        )
        super.init()

        UpdateManager.shared.setUpdater(updater)

        guard !isRunningTests else {
            return
        }

        do {
            try updater.start()
            updaterStarted = true
        } catch {
            print("Failed to start Sparkle updater: \(error)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else {
            return
        }

        bootstrapper = AppBootstrapper(updater: updater)
        windowController.setupWindow()
        observeScreenChanges()
        bootstrapper?.launch(checkForUpdates: updaterStarted)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        MainActor.assumeIsolated {
            windowController.repositionWindow()
        }
    }
}
