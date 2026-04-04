import Foundation

nonisolated protocol ClaudeExecutableLocating: Sendable {
    func locateClaudeExecutable() -> String?
}

nonisolated struct ClaudeExecutableLocator: ClaudeExecutableLocating {
    static let defaultSearchPaths: [String] = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.claude/local/claude",
    ]

    func locateClaudeExecutable() -> String? {
        for path in Self.defaultSearchPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let result, !result.isEmpty, FileManager.default.isExecutableFile(atPath: result) else {
            return nil
        }

        return result
    }
}
