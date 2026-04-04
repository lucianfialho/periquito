import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "EnglishAnalyzer")

nonisolated private struct EnglishAnalysisResult: Decodable, Sendable {
    let type: EnglishEvaluationType
    let tip: String?
    let category: String?
}

@MainActor
final class EmotionAnalyzer {
    static let shared = EmotionAnalyzer()

    private static let language = "English"

    private let historyRepository: any HistoryRepository
    private let claudeLocator: any ClaudeExecutableLocating

    init(
        historyRepository: (any HistoryRepository)? = nil,
        claudeLocator: (any ClaudeExecutableLocating)? = nil
    ) {
        self.historyRepository = historyRepository ?? FileHistoryRepository.shared
        self.claudeLocator = claudeLocator ?? ClaudeExecutableLocator()
    }

    struct AnalysisResult {
        let emotion: PeriquitoEmotion
        let intensity: Double
        let type: EnglishEvaluationType
        let tip: String?
        let category: String?
    }

    func analyze(_ prompt: String) async -> AnalysisResult {
        let start = ContinuousClock.now
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 5 else {
            logger.info("Prompt too short, skipping analysis")
            return AnalysisResult(emotion: .neutral, intensity: 0.0, type: .skip, tip: nil, category: nil)
        }

        do {
            let result = try await analyzeWithClaude(prompt: trimmed)
            let elapsed = ContinuousClock.now - start
            logger.info("English analysis took \(elapsed, privacy: .public): type=\(result.type.rawValue, privacy: .public)")

            await logToHistory(result: result, prompt: trimmed)

            switch result.type {
            case .good:
                return AnalysisResult(emotion: .happy, intensity: 0.7, type: .good, tip: result.tip, category: result.category)
            case .correction:
                return AnalysisResult(emotion: .sad, intensity: 0.6, type: .correction, tip: result.tip, category: result.category)
            case .skip, .other:
                return AnalysisResult(emotion: .neutral, intensity: 0.0, type: .skip, tip: nil, category: nil)
            }
        } catch {
            let elapsed = ContinuousClock.now - start
            logger.error("English analysis failed (\(elapsed, privacy: .public)): \(error.localizedDescription)")
            return AnalysisResult(emotion: .neutral, intensity: 0.0, type: .skip, tip: nil, category: nil)
        }
    }

    private func analyzeWithClaude(prompt: String) async throws -> EnglishAnalysisResult {
        guard let claudePath = claudeLocator.locateClaudeExecutable() else {
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
            "--output-format", "stream-json",
            "--verbose",
            "--max-turns", "1",
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["PERIQUITO_ANALYSIS_RUNNING"] = "1"
        process.environment = environment

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        process.standardInput = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let rawOutput = String(data: data, encoding: .utf8) ?? ""
                let output = Self.extractAssistantText(from: rawOutput)
                let jsonString = Self.extractJSON(from: output)

                if let jsonData = jsonString.data(using: .utf8),
                   let result = try? JSONDecoder().decode(EnglishAnalysisResult.self, from: jsonData) {
                    continuation.resume(returning: result)
                    return
                }

                continuation.resume(returning: Self.fallbackResult(from: output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated private static func extractAssistantText(from rawOutput: String) -> String {
        var textParts: [String] = []

        for line in rawOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  object["type"] as? String == "assistant",
                  let message = object["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                continue
            }

            for block in content where block["type"] as? String == "text" {
                if let text = block["text"] as? String {
                    textParts.append(text)
                }
            }
        }

        return textParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func fallbackResult(from output: String) -> EnglishAnalysisResult {
        if output.contains("\"type\":\"good\"") || output.contains("Good") {
            return EnglishAnalysisResult(type: .good, tip: nil, category: nil)
        }

        if output.contains("❌") || output.contains("→") || output.contains("correction") {
            return EnglishAnalysisResult(
                type: .correction,
                tip: String(output.prefix(200)),
                category: "other"
            )
        }

        return EnglishAnalysisResult(type: .skip, tip: nil, category: nil)
    }

    nonisolated static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        return cleaned
    }

    private func logToHistory(result: EnglishAnalysisResult, prompt: String) async {
        let entry = HistoryEntry(
            type: result.type,
            date: ISO8601DateFormatter().string(from: .now),
            prompt: String(prompt.prefix(200)),
            tip: result.tip,
            category: result.category
        )

        do {
            try await historyRepository.append(entry)
            logger.info("Logged \(result.type.rawValue, privacy: .public) to history")
        } catch {
            logger.error("Failed to log history: \(error.localizedDescription)")
        }
    }
}
