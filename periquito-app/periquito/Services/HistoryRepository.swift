import Foundation

nonisolated struct HistoryEntry: Codable, Equatable, Sendable {
    let type: EnglishEvaluationType
    let date: String
    let prompt: String
    let tip: String?
    let category: String?
}

protocol HistoryRepository: Sendable {
    func loadEntries() async throws -> [HistoryEntry]
    func append(_ entry: HistoryEntry) async throws
}

actor FileHistoryRepository: HistoryRepository {
    static let shared = FileHistoryRepository(fileURL: AppPaths.historyFile)

    nonisolated let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func loadEntries() async throws -> [HistoryEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let decoder = JSONDecoder()

        return content
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
                    return nil
                }
                return try? decoder.decode(HistoryEntry.self, from: data)
            }
    }

    func append(_ entry: HistoryEntry) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let line = String(decoding: data, as: UTF8.self)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
            try handle.close()
        } else {
            try (line + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
