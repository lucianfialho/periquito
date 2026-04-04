import AppKit
import Sparkle

@MainActor
final class AppBootstrapper {
    private let socketServer: SocketServer
    private let stateMachine: PeriquitoStateMachine
    private let levelManager: LevelManager
    private let sponsorService: SponsorService
    private let usageService: ClaudeUsageService
    private let updater: SPUUpdater

    init(
        socketServer: SocketServer? = nil,
        stateMachine: PeriquitoStateMachine? = nil,
        levelManager: LevelManager? = nil,
        sponsorService: SponsorService? = nil,
        usageService: ClaudeUsageService? = nil,
        updater: SPUUpdater
    ) {
        self.socketServer = socketServer ?? .shared
        self.stateMachine = stateMachine ?? .shared
        self.levelManager = levelManager ?? .shared
        self.sponsorService = sponsorService ?? .shared
        self.usageService = usageService ?? .shared
        self.updater = updater
    }

    func launch(checkForUpdates: Bool) {
        NSApplication.shared.setActivationPolicy(.accessory)
        startHookServices()
        usageService.startPolling()
        Task { await sponsorService.load() }

        if checkForUpdates {
            updater.checkForUpdates()
        }
    }

    private func startHookServices() {
        HookInstaller.installIfNeeded()
        levelManager.applyDecay()
        socketServer.start { event in
            Task { @MainActor in
                self.stateMachine.handleEvent(event)
            }
        }
    }
}
