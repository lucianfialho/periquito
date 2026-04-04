import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "StateMachine")

@MainActor
@Observable
final class PeriquitoStateMachine {
    static let shared = PeriquitoStateMachine()

    let sessionStore: SessionStore

    private let reducer: HookEventReducer
    private let parser: ConversationParser
    private let emotionAnalyzer: EmotionAnalyzer
    private let historyStatsLoader: HistoryStatsLoader
    private let levelManager: LevelManager
    private let spacedRepetitionManager: SpacedRepetitionManager
    private let soundService: SoundService
    private let fileWatcher: SessionFileWatcher
    private let idleQuizCoordinator: IdleQuizCoordinator

    private var emotionDecayTimer: Task<Void, Never>?
    private var pendingSyncTasks: [String: Task<Void, Never>] = [:]
    private var pendingPositionMarks: [String: Task<Void, Never>] = [:]

    private static let syncDebounce: Duration = .milliseconds(100)
    private static let waitingClearGuard: TimeInterval = 2.0

    init(
        sessionStore: SessionStore? = nil,
        parser: ConversationParser? = nil,
        emotionAnalyzer: EmotionAnalyzer? = nil,
        historyStatsLoader: HistoryStatsLoader? = nil,
        levelManager: LevelManager? = nil,
        spacedRepetitionManager: SpacedRepetitionManager? = nil,
        soundService: SoundService? = nil,
        fileWatcher: SessionFileWatcher? = nil,
        idleQuizCoordinator: IdleQuizCoordinator? = nil
    ) {
        let sessionStore = sessionStore ?? .shared
        self.sessionStore = sessionStore
        reducer = HookEventReducer(sessionStore: sessionStore)
        self.parser = parser ?? .shared
        self.emotionAnalyzer = emotionAnalyzer ?? .shared
        self.historyStatsLoader = historyStatsLoader ?? HistoryStatsLoader(repository: FileHistoryRepository.shared)
        self.levelManager = levelManager ?? .shared
        self.spacedRepetitionManager = spacedRepetitionManager ?? .shared
        self.soundService = soundService ?? .shared
        self.fileWatcher = fileWatcher ?? SessionFileWatcher()
        self.idleQuizCoordinator = idleQuizCoordinator ?? IdleQuizCoordinator()

        startEmotionDecayTimer()
        self.idleQuizCoordinator.start()
    }

    var currentState: PeriquitoState {
        sessionStore.effectiveSession?.state ?? .idle
    }

    func handleEvent(_ event: HookEvent) {
        let outcome = reducer.reduce(event)

        if outcome.shouldMarkCurrentPosition {
            pendingPositionMarks[event.sessionId] = Task {
                await parser.markCurrentPosition(sessionId: event.sessionId, cwd: event.cwd)
            }
        }

        if outcome.shouldStartFileWatcher {
            fileWatcher.startWatching(sessionId: event.sessionId, cwd: event.cwd) { [weak self] in
                self?.scheduleFileSync(sessionId: event.sessionId, cwd: event.cwd)
            }
        }

        if let prompt = outcome.promptToAnalyze {
            analyzePrompt(prompt, for: outcome.session)
        }

        if outcome.shouldPlayNotification {
            soundService.playNotificationSound(
                sessionId: event.sessionId,
                isInteractive: outcome.session.isInteractive
            )
        }

        if outcome.shouldStopFileWatcher {
            fileWatcher.stopWatching(sessionId: event.sessionId)
        }

        if outcome.shouldScheduleFileSync {
            scheduleFileSync(sessionId: event.sessionId, cwd: event.cwd)
        }

        if outcome.endedSession {
            pendingSyncTasks.removeValue(forKey: event.sessionId)?.cancel()
            pendingPositionMarks.removeValue(forKey: event.sessionId)?.cancel()
            soundService.clearCooldown(for: event.sessionId)

            if outcome.shouldResetParser {
                Task { await parser.resetState(for: event.sessionId) }
            }

            if sessionStore.activeSessionCount == 0 {
                logger.info("Global state: idle")
            }

            return
        }

        outcome.session.resetSleepTimer()
    }

    private func analyzePrompt(_ prompt: String, for session: SessionData) {
        session.isAnalyzingEnglish = true

        Task {
            let result = await emotionAnalyzer.analyze(prompt)
            session.emotionState.recordEmotion(result.emotion, intensity: result.intensity, prompt: prompt)
            session.recordEnglishTip(result, prompt: prompt)
            session.isAnalyzingEnglish = false

            let stats = await historyStatsLoader.load()
            levelManager.awardXP(for: result.type, rollingAccuracy: stats.rollingAccuracy ?? 0)

            if result.type == .correction {
                await spacedRepetitionManager.syncFromHistory()
            }
        }
    }

    private func scheduleFileSync(sessionId: String, cwd: String) {
        pendingSyncTasks[sessionId]?.cancel()

        pendingSyncTasks[sessionId] = Task {
            await pendingPositionMarks[sessionId]?.value

            try? await Task.sleep(for: Self.syncDebounce)
            guard !Task.isCancelled else {
                return
            }

            let result = await parser.parseIncremental(sessionId: sessionId, cwd: cwd)

            if !result.messages.isEmpty {
                sessionStore.recordAssistantMessages(result.messages, for: sessionId)
            }

            guard let session = sessionStore.sessions[sessionId] else {
                pendingSyncTasks.removeValue(forKey: sessionId)
                return
            }

            if result.interrupted && session.task == .working {
                session.updateTask(.idle)
                session.updateProcessingState(isProcessing: false)
            } else if session.task == .waiting,
                      Date.now.timeIntervalSince(session.lastActivity) > Self.waitingClearGuard {
                session.clearPendingQuestions()
                session.updateTask(.working)
            }

            pendingSyncTasks.removeValue(forKey: sessionId)
        }
    }

    private func startEmotionDecayTimer() {
        emotionDecayTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: EmotionState.decayInterval)
                guard !Task.isCancelled else {
                    return
                }

                for session in sessionStore.sessions.values {
                    session.emotionState.decayAll()
                }
            }
        }
    }
}
