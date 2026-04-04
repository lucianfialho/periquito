import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "SpacedRepetition")

@MainActor
@Observable
final class SpacedRepetitionManager {
    static let shared = SpacedRepetitionManager()

    private(set) var items: [QuizItem] = []
    var quizState: QuizState = .idle
    private(set) var currentQuiz: QuizItem?
    private(set) var currentOptions: [String] = []
    private let historyRepository: any HistoryRepository

    private static let reviewsFile = AppPaths.reviewsFile

    init(historyRepository: (any HistoryRepository)? = nil) {
        self.historyRepository = historyRepository ?? FileHistoryRepository.shared
        loadReviews()
    }

    // MARK: - Sync from history

    /// Scans history.jsonl for corrections not yet in review queue
    func syncFromHistory() async {
        let corrections = await DistractorEngine.loadFromHistory(repository: historyRepository)

        for correction in corrections {
            let dedupKey = correction.wrong.lowercased().trimmingCharacters(in: .whitespaces)
            let alreadyExists = items.contains {
                $0.incorrectSentence.lowercased().trimmingCharacters(in: .whitespaces) == dedupKey
            }
            guard !alreadyExists else { continue }

            let item = QuizItem(
                id: UUID().uuidString,
                incorrectSentence: correction.wrong,
                correctSentence: correction.right,
                explanation: correction.why,
                category: correction.category,
                box: 1,
                nextReviewDate: Date(),
                totalReviews: 0,
                correctCount: 0
            )
            items.append(item)
        }

        saveReviews()
        logger.info("Synced \(self.items.count) review items")
    }

    // MARK: - Quiz flow

    /// Returns the next due item, or nil if nothing is due
    func nextDueItem() -> QuizItem? {
        items
            .filter(\.isdue)
            .sorted { $0.box < $1.box } // prioritize lower boxes (harder items)
            .first
    }

    func startQuiz() -> Bool {
        guard let item = nextDueItem() else {
            logger.info("No items due for review")
            return false
        }
        currentQuiz = item
        let pool = items.map {
            HistoryCorrection(id: $0.id, wrong: $0.incorrectSentence, right: $0.correctSentence,
                              why: $0.explanation, category: $0.category)
        }
        currentOptions = DistractorEngine.options(for: item, from: pool)
        quizState = .asking(item)
        logger.info("Starting quiz for: \(item.incorrectSentence) with \(self.currentOptions.count) options")
        return true
    }

    func submitAnswer(_ answer: String) {
        guard let quiz = currentQuiz else { return }
        quizState = .evaluating

        // Multiple choice: compare selected option against correct sentence
        let isCorrect = answer == quiz.correctSentence

        // Update the item
        if let index = items.firstIndex(where: { $0.id == quiz.id }) {
            items[index].recordAnswer(correct: isCorrect)
        }

        let explanation: String
        if isCorrect {
            // Include the rule/tip so the user reinforces WHY it's correct
            if quiz.explanation.isEmpty {
                explanation = quiz.correctSentence
            } else {
                explanation = "\(quiz.correctSentence) — \(quiz.explanation)"
            }
        } else {
            explanation = "\(quiz.correctSentence) — \(quiz.explanation)"
        }

        quizState = .result(correct: isCorrect, explanation: explanation)
        saveReviews()

        // Award XP for reviews
        Task {
            let stats = await HistoryStatsLoader.load()
            LevelManager.shared.awardXP(
                for: isCorrect ? .good : .correction,
                rollingAccuracy: stats.rollingAccuracy ?? 0
            )
        }

        logger.info("Quiz answer: \(isCorrect ? "correct" : "incorrect") for '\(quiz.incorrectSentence)'")
    }

    func dismissQuiz() {
        quizState = .idle
        currentQuiz = nil
        currentOptions = []
    }

    // MARK: - Stats

    var dueCount: Int {
        items.filter(\.isdue).count
    }

    var masteredCount: Int {
        items.filter { $0.box >= 5 }.count
    }

    // MARK: - Persistence

    private func saveReviews() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: Self.reviewsFile)
    }

    private func loadReviews() {
        guard FileManager.default.fileExists(atPath: Self.reviewsFile.path),
              let data = try? Data(contentsOf: Self.reviewsFile),
              let loaded = try? JSONDecoder().decode([QuizItem].self, from: data) else {
            return
        }

        let allCorrupted = !loaded.isEmpty && loaded.allSatisfy { $0.box == 1 && $0.correctCount == 0 }
        if allCorrupted {
            logger.warning("Detected corrupted reviews data (\(loaded.count) items, all box 1). Resetting.")
            try? FileManager.default.removeItem(at: Self.reviewsFile)
            items = []
            return
        }

        items = loaded
        logger.info("Loaded \(self.items.count) review items")
    }

}
