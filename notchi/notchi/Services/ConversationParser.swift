//
//  ConversationParser.swift
//  notchi
//
//  Parses Claude JSONL conversation files to extract assistant text messages.
//  Uses incremental parsing to only read new lines since last sync.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.ruban.notchi", category: "ConversationParser")

actor ConversationParser {
    static let shared = ConversationParser()

    private var lastFileOffset: [String: UInt64] = [:]
    private var seenMessageIds: [String: Set<String>] = [:]

    /// Parse only NEW assistant text messages since last call
    func parseIncremental(sessionId: String, cwd: String) -> [AssistantMessage] {
        let sessionFile = Self.sessionFilePath(sessionId: sessionId, cwd: cwd)

        guard FileManager.default.fileExists(atPath: sessionFile) else {
            return []
        }

        guard let fileHandle = FileHandle(forReadingAtPath: sessionFile) else {
            return []
        }
        defer { try? fileHandle.close() }

        let fileSize: UInt64
        do {
            fileSize = try fileHandle.seekToEnd()
        } catch {
            return []
        }

        let lastOffset = lastFileOffset[sessionId] ?? 0

        // File was truncated or reset - start fresh
        if fileSize < lastOffset {
            lastFileOffset[sessionId] = 0
            seenMessageIds[sessionId] = []
            return parseIncremental(sessionId: sessionId, cwd: cwd)
        }

        // No new content
        if fileSize == lastOffset {
            return []
        }

        do {
            try fileHandle.seek(toOffset: lastOffset)
        } catch {
            return []
        }

        guard let newData = try? fileHandle.readToEnd(),
              let newContent = String(data: newData, encoding: .utf8) else {
            return []
        }

        var messages: [AssistantMessage] = []
        var seen = seenMessageIds[sessionId] ?? []
        let lines = newContent.components(separatedBy: "\n")

        for line in lines where !line.isEmpty {
            // Skip non-assistant messages quickly
            guard line.contains("\"type\":\"assistant\"") else { continue }

            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "assistant",
                  let uuid = json["uuid"] as? String else {
                continue
            }

            // Skip if already seen
            if seen.contains(uuid) { continue }

            // Skip meta messages
            if json["isMeta"] as? Bool == true { continue }

            guard let messageDict = json["message"] as? [String: Any] else { continue }

            // Parse timestamp
            let timestamp: Date
            if let timestampStr = json["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = formatter.date(from: timestampStr) ?? Date()
            } else {
                timestamp = Date()
            }

            // Extract text content
            var textParts: [String] = []

            if let content = messageDict["content"] as? String {
                // Skip system-like messages
                if !content.hasPrefix("<command-name>") &&
                   !content.hasPrefix("[Request interrupted") {
                    textParts.append(content)
                }
            } else if let contentArray = messageDict["content"] as? [[String: Any]] {
                for block in contentArray {
                    guard let blockType = block["type"] as? String else { continue }

                    if blockType == "text", let text = block["text"] as? String {
                        // Skip system-like messages
                        if !text.hasPrefix("[Request interrupted") {
                            textParts.append(text)
                        }
                    }
                    // Skip tool_use and thinking blocks - we only want text
                }
            }

            // Only add if we have text content
            if !textParts.isEmpty {
                let fullText = textParts.joined(separator: "\n")
                messages.append(AssistantMessage(
                    id: uuid,
                    text: fullText,
                    timestamp: timestamp
                ))
                seen.insert(uuid)
            }
        }

        lastFileOffset[sessionId] = fileSize
        seenMessageIds[sessionId] = seen

        return messages
    }

    /// Reset parsing state for a session
    func resetState(for sessionId: String) {
        lastFileOffset.removeValue(forKey: sessionId)
        seenMessageIds.removeValue(forKey: sessionId)
    }

    /// Mark the current file position as the starting point for future parsing
    /// Used when a new user prompt is submitted to ignore old messages
    func markCurrentPosition(sessionId: String, cwd: String) {
        let sessionFile = Self.sessionFilePath(sessionId: sessionId, cwd: cwd)

        guard FileManager.default.fileExists(atPath: sessionFile),
              let fileHandle = FileHandle(forReadingAtPath: sessionFile) else {
            // No file yet - clear state so we start fresh
            lastFileOffset.removeValue(forKey: sessionId)
            seenMessageIds.removeValue(forKey: sessionId)
            return
        }

        defer { try? fileHandle.close() }

        // Set offset to current end of file
        if let fileSize = try? fileHandle.seekToEnd() {
            lastFileOffset[sessionId] = fileSize
            seenMessageIds[sessionId] = []
        }
    }

    /// Build session file path from sessionId and cwd
    private static func sessionFilePath(sessionId: String, cwd: String) -> String {
        let projectDir = cwd.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")
        return "\(NSHomeDirectory())/.claude/projects/\(projectDir)/\(sessionId).jsonl"
    }
}
