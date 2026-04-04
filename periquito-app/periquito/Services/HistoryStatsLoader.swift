import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "HistoryStats")

nonisolated struct HistoryStats: Equatable, Sendable {
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

struct HistoryStatsLoader {
    private let repository: any HistoryRepository

    init(repository: any HistoryRepository) {
        self.repository = repository
    }

    func load() async -> HistoryStats {
        guard let entries = try? await repository.loadEntries() else {
            logger.error("Failed to read history file")
            return .empty
        }

        if entries.isEmpty {
            logger.info("No history file found")
            return .empty
        }

        var good = 0
        var corrections = 0
        var evaluatedTypes: [EnglishEvaluationType] = []

        for entry in entries {
            switch entry.type {
            case .good:
                good += 1
                evaluatedTypes.append(entry.type)
            case .correction:
                corrections += 1
                evaluatedTypes.append(entry.type)
            case .skip, .other:
                break
            }
        }

        let rolling: Int?
        let recent = evaluatedTypes.suffix(50)
        if recent.isEmpty {
            rolling = nil
        } else {
            let recentGood = recent.filter { $0 == .good }.count
            rolling = recentGood * 100 / recent.count
        }

        logger.info("Loaded stats: \(good) good, \(corrections) corrections, rolling: \(rolling ?? -1)%")
        return HistoryStats(totalGood: good, totalCorrections: corrections, rollingAccuracy: rolling)
    }

    static func load(repository: (any HistoryRepository)? = nil) async -> HistoryStats {
        let repository = if let repository {
            repository
        } else {
            await MainActor.run { FileHistoryRepository.shared }
        }

        return await HistoryStatsLoader(repository: repository).load()
    }
}
