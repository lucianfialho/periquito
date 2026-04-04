import SwiftUI

enum PanelTab: String, CaseIterable {
    case tips = "Tips"
    case stats = "Stats"
}

@MainActor
@Observable
final class ExpandedPanelViewModel {
    let sessionStore: SessionStore
    let quizManager: SpacedRepetitionManager
    let levelManager: LevelManager

    private let historyStatsLoader: HistoryStatsLoader

    var selectedTab: PanelTab = .tips
    var historyStats: HistoryStats?
    var accuracyDelta = 0
    var showDelta = false

    init(
        sessionStore: SessionStore,
        quizManager: SpacedRepetitionManager? = nil,
        levelManager: LevelManager? = nil,
        historyRepository: (any HistoryRepository)? = nil
    ) {
        self.sessionStore = sessionStore
        self.quizManager = quizManager ?? .shared
        self.levelManager = levelManager ?? .shared
        historyStatsLoader = HistoryStatsLoader(repository: historyRepository ?? FileHistoryRepository.shared)
    }

    var state: PeriquitoState {
        sessionStore.unifiedState
    }

    var showIndicator: Bool {
        state.task == .working || state.task == .compacting || state.task == .waiting
    }

    var tips: [EnglishTip] {
        sessionStore.allTips
    }

    var isAnalyzing: Bool {
        sessionStore.isAnyAnalyzing
    }

    var currentEmotion: PeriquitoEmotion {
        sessionStore.currentEmotion
    }

    var collapsedAccuracyColor: Color {
        guard let accuracy = historyStats?.accuracy else {
            return TerminalColors.dimmedText
        }

        if accuracy >= 80 {
            return TerminalColors.green
        }

        if accuracy >= 50 {
            return TerminalColors.amber
        }

        return Color(red: 0.95, green: 0.4, blue: 0.35)
    }

    var emptyStateTitle: String {
        HookInstaller.isInstalled() ? "Write in English!" : "Hooks not installed"
    }

    var emptyStateSubtitle: String {
        HookInstaller.isInstalled()
            ? "Periquito analyzes your English in Claude Code prompts"
            : "Open settings to set up Claude Code integration"
    }

    func selectTab(_ tab: PanelTab) {
        selectedTab = tab
    }

    func loadStats() async {
        let oldAccuracy = historyStats?.accuracy ?? 0
        historyStats = await historyStatsLoader.load()
        let newAccuracy = historyStats?.accuracy ?? 0
        let delta = newAccuracy - oldAccuracy

        if delta != 0 && oldAccuracy != 0 {
            accuracyDelta = delta
            showDelta = true
            try? await Task.sleep(for: .seconds(2.5))
            showDelta = false
        }
    }
}
