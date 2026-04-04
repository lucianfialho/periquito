import Foundation

struct HookEventOutcome {
    let session: SessionData
    let shouldMarkCurrentPosition: Bool
    let shouldStartFileWatcher: Bool
    let promptToAnalyze: String?
    let shouldPlayNotification: Bool
    let shouldScheduleFileSync: Bool
    let shouldStopFileWatcher: Bool
    let shouldResetParser: Bool
    let endedSession: Bool
}

@MainActor
struct HookEventReducer {
    let sessionStore: SessionStore

    func reduce(_ event: HookEvent) -> HookEventOutcome {
        let session = sessionStore.process(event)
        let isDone = event.status.isWaitingForInput

        switch event.event {
        case .userPromptSubmit:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: true,
                shouldStartFileWatcher: session.isInteractive,
                promptToAnalyze: session.isInteractive ? event.userPrompt : nil,
                shouldPlayNotification: false,
                shouldScheduleFileSync: false,
                shouldStopFileWatcher: false,
                shouldResetParser: false,
                endedSession: false
            )

        case .preToolUse:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: false,
                shouldStartFileWatcher: false,
                promptToAnalyze: nil,
                shouldPlayNotification: isDone,
                shouldScheduleFileSync: false,
                shouldStopFileWatcher: false,
                shouldResetParser: false,
                endedSession: false
            )

        case .permissionRequest:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: false,
                shouldStartFileWatcher: false,
                promptToAnalyze: nil,
                shouldPlayNotification: true,
                shouldScheduleFileSync: false,
                shouldStopFileWatcher: false,
                shouldResetParser: false,
                endedSession: false
            )

        case .postToolUse:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: false,
                shouldStartFileWatcher: false,
                promptToAnalyze: nil,
                shouldPlayNotification: false,
                shouldScheduleFileSync: true,
                shouldStopFileWatcher: false,
                shouldResetParser: false,
                endedSession: false
            )

        case .stop:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: false,
                shouldStartFileWatcher: false,
                promptToAnalyze: nil,
                shouldPlayNotification: true,
                shouldScheduleFileSync: true,
                shouldStopFileWatcher: true,
                shouldResetParser: false,
                endedSession: false
            )

        case .sessionEnd:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: false,
                shouldStartFileWatcher: false,
                promptToAnalyze: nil,
                shouldPlayNotification: false,
                shouldScheduleFileSync: false,
                shouldStopFileWatcher: true,
                shouldResetParser: true,
                endedSession: true
            )

        case .sessionStart, .preCompact, .subagentStop, .other:
            return HookEventOutcome(
                session: session,
                shouldMarkCurrentPosition: false,
                shouldStartFileWatcher: false,
                promptToAnalyze: nil,
                shouldPlayNotification: isDone && session.task != .idle,
                shouldScheduleFileSync: false,
                shouldStopFileWatcher: false,
                shouldResetParser: false,
                endedSession: false
            )
        }
    }
}
