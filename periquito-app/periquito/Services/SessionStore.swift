import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "SessionStore")

@MainActor
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [String: SessionData] = [:]
    private var nextSessionNumberByProject: [String: Int] = [:]

    init() {}

    var sortedSessions: [SessionData] {
        sessions.values.sorted { lhs, rhs in
            if lhs.isProcessing != rhs.isProcessing {
                return lhs.isProcessing
            }
            return lhs.lastActivity > rhs.lastActivity
        }
    }

    var activeSessionCount: Int {
        sessions.count
    }

    /// The most active session (processing first, then most recent)
    var effectiveSession: SessionData? {
        if sessions.count == 1 {
            return sessions.values.first
        }
        return sortedSessions.first
    }

    /// Unified parrot state from the most active session
    var unifiedState: PeriquitoState {
        effectiveSession?.state ?? .idle
    }

    /// Aggregated tips from ALL sessions, sorted by timestamp
    var allTips: [EnglishTip] {
        sessions.values
            .flatMap(\.englishTips)
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// True if any session is currently analyzing English
    var isAnyAnalyzing: Bool {
        sessions.values.contains { $0.isAnalyzingEnglish }
    }

    /// Current emotion from the effective session
    var currentEmotion: PeriquitoEmotion {
        effectiveSession?.state.emotion ?? .neutral
    }

    func process(_ event: HookEvent) -> SessionData {
        let isInteractive = event.interactive ?? true
        let session = getOrCreateSession(sessionId: event.sessionId, cwd: event.cwd, isInteractive: isInteractive)
        let isProcessing = event.status.isProcessing
        session.updateProcessingState(isProcessing: isProcessing)

        if let mode = event.permissionMode {
            session.updatePermissionMode(mode)
        }

        switch event.event {
        case .userPromptSubmit:
            if let prompt = event.userPrompt {
                session.recordUserPrompt(prompt)
            }
            session.clearAssistantMessages()
            session.clearPendingQuestions()
            if Self.isLocalSlashCommand(event.userPrompt) {
                session.updateTask(.idle)
            } else {
                session.updateTask(.working)
            }

        case .preCompact:
            session.updateTask(.compacting)

        case .sessionStart:
            if isProcessing {
                session.updateTask(.working)
            }

        case .preToolUse:
            let toolInput = event.toolInput?.mapValues { $0.value }
            session.recordPreToolUse(tool: event.tool, toolInput: toolInput, toolUseId: event.toolUseId)
            if event.tool == "AskUserQuestion" {
                session.updateTask(.waiting)
                session.setPendingQuestions(Self.parseQuestions(from: event.toolInput))
            } else {
                session.clearPendingQuestions()
                session.updateTask(.working)
            }

        case .permissionRequest:
            let question = Self.buildPermissionQuestion(tool: event.tool, toolInput: event.toolInput)
            session.updateTask(.waiting)
            session.setPendingQuestions([question])

        case .postToolUse:
            let success = !event.status.isError
            session.recordPostToolUse(tool: event.tool, toolUseId: event.toolUseId, success: success)
            session.clearPendingQuestions()
            session.updateTask(.working)

        case .stop, .subagentStop:
            session.clearPendingQuestions()
            session.updateTask(.idle)

        case .sessionEnd:
            session.endSession()
            removeSession(event.sessionId)

        case .other:
            if !isProcessing && session.task != .idle {
                session.updateTask(.idle)
            }
        }

        return session
    }

    func recordAssistantMessages(_ messages: [AssistantMessage], for sessionId: String) {
        guard let session = sessions[sessionId] else { return }
        session.recordAssistantMessages(messages)
    }

    private func getOrCreateSession(sessionId: String, cwd: String, isInteractive: Bool) -> SessionData {
        if let existing = sessions[sessionId] {
            return existing
        }

        let projectName = (cwd as NSString).lastPathComponent
        let sessionNumber = nextSessionNumberByProject[projectName, default: 0] + 1
        nextSessionNumberByProject[projectName] = sessionNumber
        let session = SessionData(sessionId: sessionId, cwd: cwd, sessionNumber: sessionNumber, isInteractive: isInteractive)
        sessions[sessionId] = session
        logger.info("Created session #\(sessionNumber): \(sessionId, privacy: .public) at \(cwd, privacy: .public)")
        return session
    }

    private func removeSession(_ sessionId: String) {
        sessions.removeValue(forKey: sessionId)
        logger.info("Removed session: \(sessionId, privacy: .public)")
    }

    func dismissSession(_ sessionId: String) {
        sessions[sessionId]?.endSession()
        removeSession(sessionId)
    }

    private static func parseQuestions(from toolInput: [String: AnyCodable]?) -> [PendingQuestion] {
        guard let input = toolInput?.mapValues({ $0.value }),
              let questions = input["questions"] as? [[String: Any]] else { return [] }

        return questions.compactMap { q in
            guard let questionText = q["question"] as? String else { return nil }
            let header = q["header"] as? String
            let rawOptions = q["options"] as? [[String: Any]] ?? []
            let options = rawOptions.compactMap { opt -> (label: String, description: String?)? in
                guard let label = opt["label"] as? String else { return nil }
                return (label: label, description: opt["description"] as? String)
            }
            return PendingQuestion(question: questionText, header: header, options: options)
        }
    }

    private static let localSlashCommands: Set<String> = [
        "/clear", "/help", "/cost", "/status",
        "/vim", "/fast", "/model", "/login", "/logout",
    ]

    private static func isLocalSlashCommand(_ prompt: String?) -> Bool {
        guard let prompt, prompt.hasPrefix("/") else { return false }
        let command = String(prompt.prefix(while: { !$0.isWhitespace }))
        return localSlashCommands.contains(command)
    }

    private static func buildPermissionQuestion(tool: String?, toolInput: [String: AnyCodable]?) -> PendingQuestion {
        let toolName = tool ?? "Tool"
        let input = toolInput?.mapValues { $0.value }
        let description = SessionEvent.deriveDescription(tool: tool, toolInput: input)
        return PendingQuestion(
            question: description ?? "\(toolName) wants to proceed",
            header: "Permission Request",
            // Claude Code permission prompts always present these three choices
            options: [
                (label: "Yes", description: nil),
                (label: "Yes, and don't ask again", description: nil),
                (label: "No", description: nil),
            ]
        )
    }
}
