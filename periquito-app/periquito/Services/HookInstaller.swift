import Foundation
import os.log

private let logger = Logger(subsystem: "com.lucianfialho.periquito", category: "HookInstaller")

struct HookInstaller {

    @discardableResult
    static func installIfNeeded() -> Bool {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")

        guard FileManager.default.fileExists(atPath: claudeDir.path) else {
            logger.warning("Claude Code not installed (~/.claude not found)")
            return false
        }

        let hooksDir = claudeDir.appendingPathComponent("hooks")
        let hookScript = hooksDir.appendingPathComponent("periquito-hook.sh")
        let settings = claudeDir.appendingPathComponent("settings.json")

        do {
            try FileManager.default.createDirectory(
                at: hooksDir,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create hooks directory: \(error.localizedDescription)")
            return false
        }

        if let bundled = Bundle.main.url(forResource: "periquito-hook", withExtension: "sh") {
            do {
                try? FileManager.default.removeItem(at: hookScript)
                try FileManager.default.copyItem(at: bundled, to: hookScript)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: hookScript.path
                )
                logger.info("Installed hook script to \(hookScript.path, privacy: .public)")
            } catch {
                logger.error("Failed to install hook script: \(error.localizedDescription)")
                return false
            }
        } else {
            logger.error("Hook script not found in bundle")
            return false
        }

        return updateSettings(at: settings)
    }

    private static func updateSettings(at settingsURL: URL) -> Bool {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let command = "~/.claude/hooks/periquito-hook.sh"
        let hookEntry: [[String: Any]] = [["type": "command", "command": command]]
        let withMatcher: [[String: Any]] = [["matcher": "*", "hooks": hookEntry]]
        let withoutMatcher: [[String: Any]] = [["hooks": hookEntry]]
        let preCompactConfig: [[String: Any]] = [
            ["matcher": "auto", "hooks": hookEntry],
            ["matcher": "manual", "hooks": hookEntry]
        ]

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        let hookEvents: [(String, [[String: Any]])] = [
            ("UserPromptSubmit", withoutMatcher),
            ("SessionStart", withoutMatcher),
            ("PreToolUse", withMatcher),
            ("PostToolUse", withMatcher),
            ("PermissionRequest", withMatcher),
            ("PreCompact", preCompactConfig),
            ("Stop", withoutMatcher),
            ("SubagentStop", withoutMatcher),
            ("SessionEnd", withoutMatcher),
        ]

        for (event, config) in hookEvents {
            if var existingEvent = hooks[event] as? [[String: Any]] {
                let hasOurHook = existingEvent.contains { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { h in
                            let cmd = h["command"] as? String ?? ""
                            return cmd.contains("periquito-hook.sh")
                        }
                    }
                    return false
                }
                if !hasOurHook {
                    existingEvent.append(contentsOf: config)
                    hooks[event] = existingEvent
                }
            } else {
                hooks[event] = config
            }
        }

        json["hooks"] = hooks

        guard let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            logger.error("Failed to serialize settings JSON")
            return false
        }

        do {
            try data.write(to: settingsURL)
            logger.info("Updated settings.json with Periquito hooks")
            return true
        } catch {
            logger.error("Failed to write settings.json: \(error.localizedDescription)")
            return false
        }
    }

    static func isInstalled() -> Bool {
        let settings = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settings),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        return hooks.values.contains { value in
            guard let entries = value as? [[String: Any]] else { return false }
            return entries.contains { entry in
                guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return entryHooks.contains { hook in
                    (hook["command"] as? String)?.contains("periquito-hook.sh") == true
                }
            }
        }
    }

    static func uninstall() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        let hooksDir = claudeDir.appendingPathComponent("hooks")
        let hookScript = hooksDir.appendingPathComponent("periquito-hook.sh")
        let settings = claudeDir.appendingPathComponent("settings.json")

        try? FileManager.default.removeItem(at: hookScript)

        guard let data = try? Data(contentsOf: settings),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        for (event, value) in hooks {
            if var entries = value as? [[String: Any]] {
                entries.removeAll { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { hook in
                            let cmd = hook["command"] as? String ?? ""
                            return cmd.contains("periquito-hook.sh")
                        }
                    }
                    return false
                }

                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }
        }

        if hooks.isEmpty {
            json.removeValue(forKey: "hooks")
        } else {
            json["hooks"] = hooks
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settings)
        }

        logger.info("Uninstalled Periquito hooks")
    }
}
