import Foundation
import Testing
@testable import periquito

final class MemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private var storage: [String: Any] = [:]

    func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }

    func string(forKey key: String) -> String? {
        storage[key] as? String
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}

final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "periquito-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func fileURL(named name: String) -> URL {
        url.appending(path: name)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

func makeHookEvent(
    sessionId: String = "session-1",
    cwd: String = "/tmp/periquito-project",
    event: String,
    status: String,
    tool: String? = nil,
    toolInput: [String: Any]? = nil,
    toolUseId: String? = nil,
    userPrompt: String? = nil,
    permissionMode: String? = nil,
    interactive: Bool? = true
) throws -> HookEvent {
    var payload: [String: Any] = [
        "session_id": sessionId,
        "cwd": cwd,
        "event": event,
        "status": status,
    ]

    if let tool {
        payload["tool"] = tool
    }

    if let toolInput {
        payload["tool_input"] = toolInput
    }

    if let toolUseId {
        payload["tool_use_id"] = toolUseId
    }

    if let userPrompt {
        payload["user_prompt"] = userPrompt
    }

    if let permissionMode {
        payload["permission_mode"] = permissionMode
    }

    if let interactive {
        payload["interactive"] = interactive
    }

    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder().decode(HookEvent.self, from: data)
}
