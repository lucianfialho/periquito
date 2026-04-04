import AppKit
import Foundation
import os.log

private let idleQuizLogger = Logger(subsystem: "com.lucianfialho.periquito", category: "IdleQuizCoordinator")

@MainActor
final class IdleQuizCoordinator {
    private let idleDetector: IdleDetector
    private let quizManager: SpacedRepetitionManager
    private let panelManager: NotchPanelManager
    private var idleQuizTimer: Task<Void, Never>?
    private var hasStarted = false

    init(
        idleDetector: IdleDetector? = nil,
        quizManager: SpacedRepetitionManager? = nil,
        panelManager: NotchPanelManager? = nil
    ) {
        self.idleDetector = idleDetector ?? .shared
        self.quizManager = quizManager ?? .shared
        self.panelManager = panelManager ?? .shared
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        idleDetector.start()

        Task {
            await quizManager.syncFromHistory()
        }

        idleQuizTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else {
                    return
                }

                if idleDetector.shouldTriggerQuiz() {
                    await quizManager.syncFromHistory()

                    if quizManager.quizState == .idle && quizManager.startQuiz() {
                        idleDetector.recordQuizTriggered()
                        panelManager.expand()
                        NSSound(named: .periquitoPop)?.play()
                        idleQuizLogger.info("Triggered spaced repetition quiz (idle on: \(self.idleDetector.detectedApp ?? "unknown"))")
                    }
                }
            }
        }
    }

    func stop() {
        idleQuizTimer?.cancel()
        idleQuizTimer = nil
        hasStarted = false
        idleDetector.stop()
    }
}
