import Foundation
import os.log

private let logger = Logger(subsystem: "com.ruban.periquito", category: "EnglishAnalyzer")

private struct EnglishAnalysisResult: Decodable, Sendable {
    let type: String          // "correction", "good", "skip"
    let tip: String?          // correction tip text
    let category: String?     // "grammar", "spelling", "word_choice", "phrasing", "punctuation"
}

@MainActor
final class EmotionAnalyzer {
    static let shared = EmotionAnalyzer()

    private static let language = "English"

    private static let historyDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var historyFile: URL {
        historyDir.appendingPathComponent("history.jsonl")
    }

    private init() {}

    struct AnalysisResult {
        let emotion: String
        let intensity: Double
        let type: String       // "good", "correction", "skip"
        let tip: String?
        let category: String?
    }

    func analyze(_ prompt: String) async -> AnalysisResult {
        let start = ContinuousClock.now

        // Skip very short prompts (likely not real English)
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            logger.info("Prompt too short, skipping analysis")
            return AnalysisResult(emotion: "neutral", intensity: 0.0, type: "skip", tip: nil, category: nil)
        }

        do {
            let result = try await analyzeWithClaude(prompt: trimmed)
            let elapsed = ContinuousClock.now - start
            logger.info("English analysis took \(elapsed, privacy: .public): type=\(result.type, privacy: .public)")

            // Log to history
            logToHistory(result: result, prompt: trimmed)

            // Map result to emotion
            switch result.type {
            case "good":
                return AnalysisResult(emotion: "happy", intensity: 0.7, type: "good", tip: result.tip, category: result.category)
            case "correction":
                return AnalysisResult(emotion: "sad", intensity: 0.6, type: "correction", tip: result.tip, category: result.category)
            default:
                return AnalysisResult(emotion: "neutral", intensity: 0.0, type: "skip", tip: nil, category: nil)
            }
        } catch {
            let elapsed = ContinuousClock.now - start
            logger.error("English analysis failed (\(elapsed, privacy: .public)): \(error.localizedDescription)")
            return AnalysisResult(emotion: "neutral", intensity: 0.0, type: "skip", tip: nil, category: nil)
        }
    }

    private func analyzeWithClaude(prompt: String) async throws -> EnglishAnalysisResult {
        // Find claude binary
        let claudePath = Self.findClaude()
        guard let claudePath else {
            logger.error("Claude CLI not found in PATH")
            throw NSError(domain: "EnglishAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Claude CLI not found"])
        }

        let analysisPrompt = """
            You are a concise \(Self.language) tutor for a Brazilian Portuguese speaker. \
            Analyze this text written/spoken in \(Self.language). \
            If you find grammar mistakes, unnatural phrasing, wrong word choices, or pronunciation-related spelling errors, \
            respond with ONLY valid JSON (no markdown, no backticks): \
            {"type":"correction","tip":"the tip text here","category":"grammar|spelling|word_choice|phrasing|punctuation"}. \
            The tip format should be: ❌ [what they said] → ✅ [correction] — [brief why]. \
            If the text is NOT in \(Self.language), respond with: {"type":"skip"}. \
            If the \(Self.language) is good, respond with a helpful tip — suggest a synonym, \
            a more natural phrasing, an idiom, a phrasal verb, or a vocabulary upgrade related to what they wrote. \
            Format: {"type":"good","tip":"💡 tip text here","category":"vocabulary|idiom|phrasal_verb|synonym|expression"}. \
            Keep the tip short (under 80 chars), practical, and relevant to their text. \
            Text: "\(prompt)"
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "-p", analysisPrompt,
            "--output-format", "text",
            "--max-turns", "1",
            "--settings", "{}"
        ]

        // Set environment to avoid recursive hooks
        var env = ProcessInfo.processInfo.environment
        env["PERIQUITO_ANALYSIS_RUNNING"] = "1"
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let jsonString = EmotionAnalyzer.extractJSON(from: output)

                if let jsonData = jsonString.data(using: .utf8),
                   let result = try? JSONDecoder().decode(EnglishAnalysisResult.self, from: jsonData) {
                    continuation.resume(returning: result)
                } else {
                    // Fallback: try to detect type from text
                    if output.contains("\"type\":\"good\"") || output.contains("Good") {
                        continuation.resume(returning: EnglishAnalysisResult(type: "good", tip: nil, category: nil))
                    } else if output.contains("❌") || output.contains("→") || output.contains("correction") {
                        continuation.resume(returning: EnglishAnalysisResult(type: "correction", tip: String(output.prefix(200)), category: "other"))
                    } else {
                        continuation.resume(returning: EnglishAnalysisResult(type: "skip", tip: nil, category: nil))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func findClaude() -> String? {
        // Check common locations
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.claude/local/claude"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let result, !result.isEmpty, FileManager.default.isExecutableFile(atPath: result) {
            return result
        }

        return nil
    }

    nonisolated static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code blocks
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find first { to last }
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        return cleaned
    }

    private func logToHistory(result: EnglishAnalysisResult, prompt: String) {
        let today = ISO8601DateFormatter().string(from: Date())
        var entry: [String: Any] = [
            "type": result.type,
            "date": today,
            "prompt": String(prompt.prefix(200))
        ]
        if let tip = result.tip {
            entry["tip"] = tip
        }
        if let category = result.category {
            entry["category"] = category
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              let line = String(data: data, encoding: .utf8) else { return }

        let fileURL = Self.historyFile
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            handle.closeFile()
        } else {
            try? (line + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }

        logger.info("Logged \(result.type, privacy: .public) to history")
    }
}
