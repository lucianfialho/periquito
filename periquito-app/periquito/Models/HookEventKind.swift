import Foundation

nonisolated enum HookEventKind: Codable, Equatable, Hashable, Sendable {
    case userPromptSubmit
    case sessionStart
    case preToolUse
    case postToolUse
    case permissionRequest
    case preCompact
    case stop
    case subagentStop
    case sessionEnd
    case other(String)

    init(rawValue: String) {
        switch rawValue {
        case "UserPromptSubmit":
            self = .userPromptSubmit
        case "SessionStart":
            self = .sessionStart
        case "PreToolUse":
            self = .preToolUse
        case "PostToolUse":
            self = .postToolUse
        case "PermissionRequest":
            self = .permissionRequest
        case "PreCompact":
            self = .preCompact
        case "Stop":
            self = .stop
        case "SubagentStop":
            self = .subagentStop
        case "SessionEnd":
            self = .sessionEnd
        default:
            self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .userPromptSubmit:
            "UserPromptSubmit"
        case .sessionStart:
            "SessionStart"
        case .preToolUse:
            "PreToolUse"
        case .postToolUse:
            "PostToolUse"
        case .permissionRequest:
            "PermissionRequest"
        case .preCompact:
            "PreCompact"
        case .stop:
            "Stop"
        case .subagentStop:
            "SubagentStop"
        case .sessionEnd:
            "SessionEnd"
        case .other(let value):
            value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = HookEventKind(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum HookProcessingStatus: Codable, Equatable, Hashable, Sendable {
    case waitingForInput
    case error
    case other(String)

    init(rawValue: String) {
        switch rawValue {
        case "waiting_for_input":
            self = .waitingForInput
        case "error":
            self = .error
        default:
            self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .waitingForInput:
            "waiting_for_input"
        case .error:
            "error"
        case .other(let value):
            value
        }
    }

    var isWaitingForInput: Bool {
        if case .waitingForInput = self {
            true
        } else {
            false
        }
    }

    var isError: Bool {
        if case .error = self {
            true
        } else {
            false
        }
    }

    var isProcessing: Bool {
        !isWaitingForInput
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = HookProcessingStatus(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
