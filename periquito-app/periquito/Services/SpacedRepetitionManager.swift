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

    private static let reviewsFile: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reviews.json")
    }()

    private static var historyFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
            .appendingPathComponent("history.jsonl")
    }

    private init() {
        loadReviews()
    }

    // MARK: - Sync from history

    /// Scans history.jsonl for corrections not yet in review queue
    func syncFromHistory() async {
        let corrections = await loadCorrections()
        var existingIds = Set(items.map(\.id))

        for correction in corrections {
            let id = correction.id
            guard !existingIds.contains(id) else { continue }
            existingIds.insert(id)

            let item = QuizItem(
                id: id,
                incorrectSentence: correction.wrong,
                correctSentence: correction.right,
                explanation: correction.why,
                category: correction.category,
                box: 1,
                nextReviewDate: Date(), // due immediately
                totalReviews: 0,
                correctCount: 0
            )
            items.append(item)
        }

        saveReviews()
        logger.info("Synced \(self.items.count) review items (\(corrections.count) corrections in history)")
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
        quizState = .asking(item)
        logger.info("Starting quiz for: \(item.incorrectSentence)")
        return true
    }

    func submitAnswer(_ answer: String) {
        guard let quiz = currentQuiz else { return }
        quizState = .evaluating

        // Multiple choice: compare selected option against correct sentence
        let correct = quiz.correctSentence.components(separatedBy: " / ").first ?? quiz.correctSentence
        let isCorrect = answer == correct

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
            LevelManager.shared.awardXP(for: isCorrect ? "good" : "correction", rollingAccuracy: stats.rollingAccuracy ?? 0)
        }

        logger.info("Quiz answer: \(isCorrect ? "correct" : "incorrect") for '\(quiz.incorrectSentence)'")
    }

    func dismissQuiz() {
        quizState = .idle
        currentQuiz = nil
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
        items = loaded
        logger.info("Loaded \(self.items.count) review items")
    }

    // MARK: - History parsing

    private struct CorrectionEntry {
        let id: String
        let wrong: String
        let right: String
        let why: String
        let category: String
    }

    private func loadCorrections() async -> [CorrectionEntry] {
        let fileURL = Self.historyFile
        return await Task.detached {
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return []
            }

            var corrections: [CorrectionEntry] = []
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let data = trimmed.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = obj["type"] as? String,
                      type == "correction",
                      let tip = obj["tip"] as? String else { continue }

                let category = obj["category"] as? String ?? "grammar"

                // Parse "❌ X → ✅ Y — Z" format
                let parsed = Self.parseTip(tip)
                guard !parsed.wrong.isEmpty, !parsed.right.isEmpty else { continue }

                // Use hash of tip as stable ID
                let id = String(format: "%08x", tip.hashValue & 0xFFFFFFFF)
                corrections.append(CorrectionEntry(
                    id: id,
                    wrong: parsed.wrong,
                    right: parsed.right,
                    why: parsed.why,
                    category: category
                ))
            }
            return corrections
        }.value
    }

    nonisolated private static func parseTip(_ tip: String) -> (wrong: String, right: String, why: String) {
        // Handle multi-correction tips: take first one
        let segment = tip.components(separatedBy: "; ").first ?? tip

        guard let arrowRange = segment.range(of: " → ") else {
            return ("", "", segment)
        }

        let wrongPart = String(segment[segment.startIndex..<arrowRange.lowerBound])
            .replacingOccurrences(of: "❌ ", with: "")
            .replacingOccurrences(of: "❌", with: "")
            .trimmingCharacters(in: .whitespaces)

        let afterArrow = String(segment[arrowRange.upperBound...])

        if let dashRange = afterArrow.range(of: " — ") {
            let rightPart = String(afterArrow[afterArrow.startIndex..<dashRange.lowerBound])
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .trimmingCharacters(in: .whitespaces)
            let why = String(afterArrow[dashRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            return (wrongPart, rightPart, why)
        } else {
            let rightPart = afterArrow
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .trimmingCharacters(in: .whitespaces)
            return (wrongPart, rightPart, "")
        }
    }

    // MARK: - String similarity

    private func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count
        guard m > 0, n > 0 else { return m == n ? 1.0 : 0.0 }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }

        let distance = dp[m][n]
        return 1.0 - Double(distance) / Double(max(m, n))
    }
}
