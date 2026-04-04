import Foundation

/// Shared type representing a parsed correction from history.jsonl
nonisolated struct HistoryCorrection {
    let id: String
    let wrong: String
    let right: String
    let why: String
    let category: String
}

/// Builds shuffled quiz option arrays from correction history.
nonisolated struct DistractorEngine {

    /// Returns shuffled quiz options for a quiz item.
    /// - Pulls up to 2 extra distractors from the same category in `corrections`.
    /// - Falls back to [correctSentence, incorrectSentence] if not enough history.
    static func options(for item: QuizItem, from corrections: [HistoryCorrection]) -> [String] {
        let sameCategory = corrections.filter {
            $0.category == item.category && $0.wrong != item.incorrectSentence
        }

        let distractors = Array(sameCategory.shuffled().prefix(2).map(\.wrong))
        let pool = [item.correctSentence, item.incorrectSentence] + distractors
        return pool.shuffled()
    }

    /// Loads and parses all corrections from history.jsonl.
    static func loadFromHistory(
        repository: (any HistoryRepository)? = nil
    ) async -> [HistoryCorrection] {
        let repository = if let repository {
            repository
        } else {
            await MainActor.run { FileHistoryRepository.shared }
        }

        guard let entries = try? await repository.loadEntries() else {
            return []
        }

        return entries.compactMap { entry in
            guard entry.type == .correction, let tip = entry.tip else {
                return nil
            }

            let parsed = parseTip(tip)
            guard !parsed.wrong.isEmpty, !parsed.right.isEmpty else {
                return nil
            }

            return HistoryCorrection(
                id: UUID().uuidString,
                wrong: parsed.wrong,
                right: parsed.right,
                why: parsed.why,
                category: entry.category ?? "grammar"
            )
        }
    }

    // MARK: - Tip parsing

    static func parseTip(_ tip: String) -> (wrong: String, right: String, why: String) {
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
            let fullRight = String(afterArrow[afterArrow.startIndex..<dashRange.lowerBound])
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .trimmingCharacters(in: .whitespaces)
            let rightMain = fullRight.components(separatedBy: " / ").first?
                .trimmingCharacters(in: .whitespaces) ?? fullRight
            let why = String(afterArrow[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (wrongPart, rightMain, why)
        } else {
            let fullRight = afterArrow
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .trimmingCharacters(in: .whitespaces)
            let rightMain = fullRight.components(separatedBy: " / ").first?
                .trimmingCharacters(in: .whitespaces) ?? fullRight
            return (wrongPart, rightMain, "")
        }
    }
}
