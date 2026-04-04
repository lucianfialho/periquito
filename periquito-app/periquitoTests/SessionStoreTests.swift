import Testing
@testable import periquito

@MainActor
struct SessionStoreTests {
    @Test("AskUserQuestion moves the session into waiting state and stores parsed questions")
    func askUserQuestionCreatesPendingQuestion() throws {
        let store = SessionStore()
        let event = try makeHookEvent(
            event: "PreToolUse",
            status: "running",
            tool: "AskUserQuestion",
            toolInput: [
                "questions": [
                    [
                        "header": "Tone",
                        "question": "Choose a tone",
                        "options": [
                            ["label": "Friendly", "description": "More casual"],
                            ["label": "Formal", "description": "More business-like"],
                        ],
                    ],
                ],
            ],
            toolUseId: "tool-1"
        )

        let session = store.process(event)

        #expect(session.task == .waiting)
        #expect(session.pendingQuestions.count == 1)
        #expect(session.pendingQuestions.first?.header == "Tone")
        #expect(session.pendingQuestions.first?.question == "Choose a tone")
        #expect(session.pendingQuestions.first?.options.count == 2)
        #expect(session.pendingQuestions.first?.options.first?.label == "Friendly")
    }

    @Test("Local slash commands keep the session idle on prompt submit")
    func localSlashCommandsDoNotSetWorkingState() throws {
        let store = SessionStore()
        let event = try makeHookEvent(
            event: "UserPromptSubmit",
            status: "running",
            userPrompt: "/clear"
        )

        let session = store.process(event)

        #expect(session.task == .idle)
        #expect(session.lastUserPrompt == "/clear")
    }

    @Test("SessionEnd removes the session from the store")
    func sessionEndRemovesStoredSession() throws {
        let store = SessionStore()

        _ = store.process(try makeHookEvent(event: "SessionStart", status: "running"))
        _ = store.process(try makeHookEvent(event: "SessionEnd", status: "completed"))

        #expect(store.activeSessionCount == 0)
        #expect(store.sessions["session-1"] == nil)
    }
}
