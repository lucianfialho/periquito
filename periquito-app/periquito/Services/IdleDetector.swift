import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.ruban.periquito", category: "IdleDetector")

@MainActor
@Observable
final class IdleDetector {
    static let shared = IdleDetector()

    private(set) var isIdle = false
    private(set) var idleSince: Date?
    private(set) var detectedApp: String?

    private var pollTimer: Task<Void, Never>?
    private var idleStartTime: Date?

    /// How long the user must be on a procrastination app before triggering quiz (seconds)
    private static let idleThreshold: TimeInterval = 120 // 2 minutes

    /// How often to poll the frontmost app (seconds)
    private static let pollInterval: Duration = .seconds(15)

    /// Minimum time between quizzes (seconds)
    private static let quizCooldown: TimeInterval = 300 // 5 minutes
    private var lastQuizTime: Date?

    /// Bundle IDs considered "procrastination" — browsers are checked separately via title
    private static let procrastinationApps: Set<String> = [
        // Streaming
        "com.spotify.client",
        "com.apple.TV",
        // Social
        "com.tinyspeck.slackmacgap",  // Slack (non-work chat)
        "com.hnc.Discord",
        "com.facebook.archon",         // Messenger
        "com.telegram.desktop",
        "com.whatsapp.WhatsApp",
    ]

    /// Browser bundle IDs
    private static let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "com.brave.Browser",
        "company.thebrowser.Browser", // Arc
        "com.operasoftware.Opera",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
    ]

    /// URL/title patterns that suggest procrastination in a browser
    private static let procrastinationPatterns: [String] = [
        "youtube.com", "youtube", "YouTube",
        "twitter.com", "x.com", "Twitter", "X -",
        "reddit.com", "Reddit",
        "instagram.com", "Instagram",
        "tiktok.com", "TikTok",
        "facebook.com", "Facebook",
        "netflix.com", "Netflix",
        "twitch.tv", "Twitch",
        "9gag.com",
    ]

    /// Terminal/IDE bundle IDs (productive apps)
    private static let productiveApps = TerminalFocusDetector.terminalBundleIds

    private init() {}

    func start() {
        guard pollTimer == nil else { return }
        logger.info("Starting idle detector")

        pollTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                checkFrontmostApp()
            }
        }
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        isIdle = false
        idleStartTime = nil
        detectedApp = nil
        logger.info("Stopped idle detector")
    }

    /// Returns true if a quiz should be triggered now
    func shouldTriggerQuiz() -> Bool {
        guard isIdle,
              let start = idleStartTime,
              Date().timeIntervalSince(start) >= Self.idleThreshold else {
            return false
        }

        // Check cooldown
        if let lastQuiz = lastQuizTime,
           Date().timeIntervalSince(lastQuiz) < Self.quizCooldown {
            return false
        }

        return true
    }

    func recordQuizTriggered() {
        lastQuizTime = Date()
    }

    private func checkFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier else {
            resetIdle()
            return
        }

        // Check if it's a productive app — reset idle if so
        if Self.productiveApps.contains(bundleId) {
            resetIdle()
            return
        }

        // Check direct procrastination apps
        if Self.procrastinationApps.contains(bundleId) {
            markIdle(app: app.localizedName ?? bundleId)
            return
        }

        // Check browsers — need to inspect window title
        if Self.browserBundleIds.contains(bundleId) {
            let title = getActiveWindowTitle() ?? ""
            let isProcrastinating = Self.procrastinationPatterns.contains { pattern in
                title.localizedCaseInsensitiveContains(pattern)
            }
            if isProcrastinating {
                markIdle(app: title.prefix(40).description)
                return
            }
        }

        // Not a known procrastination scenario — reset
        resetIdle()
    }

    private func markIdle(app: String) {
        if !isIdle {
            idleStartTime = Date()
            isIdle = true
            detectedApp = app
            logger.info("Procrastination detected: \(app)")
        }
    }

    private func resetIdle() {
        if isIdle {
            logger.debug("User returned to productive app")
        }
        isIdle = false
        idleStartTime = nil
        detectedApp = nil
    }

    /// Gets the title of the frontmost window using Accessibility API
    private func getActiveWindowTitle() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success else { return nil }

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success else { return nil }

        return title as? String
    }
}

