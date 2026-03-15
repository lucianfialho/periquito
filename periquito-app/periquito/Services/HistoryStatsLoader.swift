import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "HistoryStats")

struct HistoryStats: Sendable {
    let totalGood: Int
    let totalCorrections: Int
    let rollingAccuracy: Int?

    var totalEvaluated: Int { totalGood + totalCorrections }

    /// Accuracy as 0-100 integer. Returns nil if no evaluated prompts.
    var accuracy: Int? {
        guard totalEvaluated > 0 else { return nil }
        return totalGood * 100 / totalEvaluated
    }

    static let empty = HistoryStats(totalGood: 0, totalCorrections: 0, rollingAccuracy: nil)
}

enum HistoryStatsLoader {
    private static var historyFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
            .appendingPathComponent("history.jsonl")
    }

    static func load() async -> HistoryStats {
        let fileURL = historyFile
        return await Task.detached {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                logger.info("No history file found")
                return HistoryStats.empty
            }

            guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else {
                logger.error("Failed to read history file")
                return HistoryStats.empty
            }

            var good = 0
            var corrections = 0
            var evaluatedTypes: [String] = []

            for line in data.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let lineData = trimmed.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let type = obj["type"] as? String else {
                    continue
                }

                switch type {
                case "good":
                    good += 1
                    evaluatedTypes.append(type)
                case "correction":
                    corrections += 1
                    evaluatedTypes.append(type)
                default: break
                }
            }

            // Rolling accuracy: last 50 evaluated entries
            let rolling: Int?
            let recent = evaluatedTypes.suffix(50)
            if recent.isEmpty {
                rolling = nil
            } else {
                let recentGood = recent.filter { $0 == "good" }.count
                rolling = recentGood * 100 / recent.count
            }

            logger.info("Loaded stats: \(good) good, \(corrections) corrections, rolling: \(rolling ?? -1)%")
            return HistoryStats(totalGood: good, totalCorrections: corrections, rollingAccuracy: rolling)
        }.value
    }
}
