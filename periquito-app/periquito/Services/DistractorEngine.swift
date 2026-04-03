import Foundation

/// Shared type representing a parsed correction from history.jsonl
struct HistoryCorrection {
    let id: String
    let wrong: String
    let right: String
    let why: String
    let category: String
}

/// Builds shuffled quiz option arrays from correction history.
struct DistractorEngine {

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
    static func loadFromHistory() async -> [HistoryCorrection] {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
            .appendingPathComponent("history.jsonl")

        return await Task.detached {
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return []
            }

            var corrections: [HistoryCorrection] = []
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let data = trimmed.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = obj["type"] as? String,
                      type == "correction",
                      let tip = obj["tip"] as? String else { continue }

                let category = obj["category"] as? String ?? "grammar"
                let parsed = parseTip(tip)
                guard !parsed.wrong.isEmpty, !parsed.right.isEmpty else { continue }

                let id = UUID().uuidString
                corrections.append(HistoryCorrection(
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
