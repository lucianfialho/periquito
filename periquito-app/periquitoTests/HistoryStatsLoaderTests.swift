import Foundation
import Testing
@testable import periquito

@MainActor
struct HistoryStatsLoaderTests {
    @Test("Loads aggregated stats from a temporary history file")
    func loadsStatsFromTemporaryFile() async throws {
        let directory = try TemporaryDirectory()
        let repository = FileHistoryRepository(fileURL: directory.fileURL(named: "history.jsonl"))

        try await repository.append(
            HistoryEntry(type: .good, date: "2026-04-04T10:00:00Z", prompt: "Prompt 1", tip: "Tip 1", category: "vocabulary")
        )
        try await repository.append(
            HistoryEntry(type: .correction, date: "2026-04-04T10:01:00Z", prompt: "Prompt 2", tip: "Tip 2", category: "grammar")
        )
        try await repository.append(
            HistoryEntry(type: .good, date: "2026-04-04T10:02:00Z", prompt: "Prompt 3", tip: "Tip 3", category: "phrasing")
        )

        let stats = await HistoryStatsLoader(repository: repository).load()

        #expect(stats.totalGood == 2)
        #expect(stats.totalCorrections == 1)
        #expect(stats.accuracy == 66)
        #expect(stats.rollingAccuracy == 66)
    }
}
