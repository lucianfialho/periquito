import Foundation

nonisolated struct HookEvent: Decodable, Sendable {
    let sessionId: String
    let cwd: String
    let event: HookEventKind
    let status: HookProcessingStatus
    let pid: Int?
    let tty: String?
    let tool: String?
    let toolInput: [String: AnyCodable]?
    let toolUseId: String?
    let userPrompt: String?
    let permissionMode: String?
    let interactive: Bool?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd, event, status, pid, tty, tool
        case toolInput = "tool_input"
        case toolUseId = "tool_use_id"
        case userPrompt = "user_prompt"
        case permissionMode = "permission_mode"
        case interactive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        cwd = try container.decode(String.self, forKey: .cwd)
        event = HookEventKind(rawValue: try container.decode(String.self, forKey: .event))
        status = HookProcessingStatus(rawValue: try container.decode(String.self, forKey: .status))
        pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        tty = try container.decodeIfPresent(String.self, forKey: .tty)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        toolInput = try container.decodeIfPresent([String: AnyCodable].self, forKey: .toolInput)
        toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt)
        permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        interactive = try container.decodeIfPresent(Bool.self, forKey: .interactive)
    }
}

nonisolated struct AnyCodable: Decodable, @unchecked Sendable {
    nonisolated(unsafe) let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
}
