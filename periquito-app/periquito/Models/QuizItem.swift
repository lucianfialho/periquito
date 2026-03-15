import Foundation

struct QuizItem: Identifiable, Codable, Equatable {
    let id: String
    let incorrectSentence: String
    let correctSentence: String
    let explanation: String
    let category: String

    /// Spaced repetition state
    var box: Int  // Leitner box 1-5
    var nextReviewDate: Date
    var totalReviews: Int
    var correctCount: Int

    var isdue: Bool {
        Date() >= nextReviewDate
    }

    /// Intervals per box: 1h, 1d, 3d, 7d, 14d
    static let intervals: [TimeInterval] = [
        3600,         // box 1: 1 hour
        86400,        // box 2: 1 day
        86400 * 3,    // box 3: 3 days
        86400 * 7,    // box 4: 7 days
        86400 * 14    // box 5: 14 days (mastered)
    ]

    mutating func recordAnswer(correct: Bool) {
        totalReviews += 1
        if correct {
            correctCount += 1
            box = min(box + 1, 5)
        } else {
            box = max(box - 1, 1)
        }
        let interval = Self.intervals[min(box - 1, Self.intervals.count - 1)]
        nextReviewDate = Date().addingTimeInterval(interval)
    }
}

enum QuizState: Equatable {
    case idle
    case asking(QuizItem)
    case evaluating
    case result(correct: Bool, explanation: String)
}
