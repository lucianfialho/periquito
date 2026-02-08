import SwiftUI

enum ActivityItem: Identifiable {
    case tool(SessionEvent)
    case assistant(AssistantMessage)

    var id: String {
        switch self {
        case .tool(let event): return "tool-\(event.id.uuidString)"
        case .assistant(let msg): return "assistant-\(msg.id)"
        }
    }

    var timestamp: Date {
        switch self {
        case .tool(let event): return event.timestamp
        case .assistant(let msg): return msg.timestamp
        }
    }
}

struct ExpandedPanelView: View {
    let sessionStore: SessionStore
    let usageService: ClaudeUsageService
    @Binding var showingSettings: Bool
    @Binding var showingCredentials: Bool
    @Binding var showingSessionActivity: Bool
    @Binding var isActivityCollapsed: Bool
    let onSettingsTap: () -> Void

    private var effectiveSession: SessionData? {
        sessionStore.effectiveSession
    }

    private var state: NotchiState {
        effectiveSession?.state ?? .idle
    }

    private var showIndicator: Bool {
        state.task == .working || state.task == .compacting
    }

    private var hasActivity: Bool {
        guard let session = effectiveSession else { return false }
        return !session.recentEvents.isEmpty ||
               !session.recentAssistantMessages.isEmpty ||
               session.isProcessing ||
               showIndicator ||
               session.lastUserPrompt != nil
    }

    private var unifiedActivityItems: [ActivityItem] {
        guard let session = effectiveSession else { return [] }
        let toolItems = session.recentEvents.map { ActivityItem.tool($0) }
        let messageItems = session.recentAssistantMessages.map { ActivityItem.assistant($0) }
        return (toolItems + messageItems).sorted { $0.timestamp < $1.timestamp }
    }

    private var shouldShowSessionPicker: Bool {
        sessionStore.activeSessionCount >= 2 && !showingSessionActivity
    }

    var body: some View {
        GeometryReader { geometry in
            if showingCredentials {
                CredentialsFormView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if showingSettings {
                PanelSettingsView(showingCredentials: $showingCredentials)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if shouldShowSessionPicker {
                sessionPickerContent(geometry: geometry)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                activityContent(geometry: geometry)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSettings)
        .animation(.easeInOut(duration: 0.25), value: showingCredentials)
        .animation(.easeInOut(duration: 0.25), value: shouldShowSessionPicker)
    }

    @ViewBuilder
    private func sessionPickerContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: geometry.size.height * 0.3)

            VStack(alignment: .leading, spacing: 0) {
                Divider().background(Color.white.opacity(0.08))

                SessionListView(
                    sessions: sessionStore.sortedSessions,
                    selectedSessionId: sessionStore.selectedSessionId,
                    onSelectSession: { sessionId in
                        sessionStore.selectSession(sessionId)
                        showingSessionActivity = true
                    },
                    onDeleteSession: { sessionId in
                        sessionStore.dismissSession(sessionId)
                    }
                )

                UsageBarView(
                    usage: usageService.currentUsage,
                    isLoading: usageService.isLoading,
                    error: usageService.error,
                    onSettingsTap: onSettingsTap
                )
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func activityContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isActivityCollapsed {
                Spacer()
            } else {
                Spacer()
                    .frame(height: geometry.size.height * 0.3)
            }

            VStack(alignment: .leading, spacing: 0) {
                if hasActivity {
                    Divider().background(Color.white.opacity(0.08))
                    activitySection
                } else if !isActivityCollapsed {
                    Spacer()
                    emptyState
                    Spacer()
                }

                UsageBarView(
                    usage: usageService.currentUsage,
                    isLoading: usageService.isLoading,
                    error: usageService.error,
                    onSettingsTap: onSettingsTap
                )
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isActivityCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if let session = effectiveSession {
                            Text("Notchi #\(session.sessionNumber)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(TerminalColors.secondaryText)
                        }

                        Spacer()

                        if let mode = effectiveSession?.currentModeDisplay {
                            ModeBadgeView(mode: mode)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if let prompt = effectiveSession?.lastUserPrompt {
                                    UserPromptBubbleView(text: prompt)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.bottom, 8)
                                }

                                ForEach(unifiedActivityItems) { item in
                                    switch item {
                                    case .tool(let event):
                                        ActivityRowView(event: event)
                                            .id(item.id)
                                    case .assistant(let message):
                                        AssistantTextRowView(message: message)
                                            .id(item.id)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .onAppear {
                            if let lastItem = unifiedActivityItems.last {
                                proxy.scrollTo(lastItem.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: unifiedActivityItems.last?.id) { _, newId in
                            if let id = newId {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    if showIndicator {
                        WorkingIndicatorView(state: state)
                            .padding(.top, 4)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Waiting for activity")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(TerminalColors.secondaryText)
            Text("Send a message in Claude Code to start tracking")
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PanelHeaderButton: View {
    let sfSymbol: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: sfSymbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(isHovered ? TerminalColors.hoverBackground : TerminalColors.subtleBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ModeBadgeView: View {
    let mode: String

    var body: some View {
        Text(mode)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(TerminalColors.secondaryText)
    }
}
