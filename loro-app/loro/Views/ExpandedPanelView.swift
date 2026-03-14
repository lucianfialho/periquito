import SwiftUI

struct ExpandedPanelView: View {
    let sessionStore: SessionStore
    let usageService: ClaudeUsageService
    @Binding var showingSettings: Bool
    @Binding var showingSessionActivity: Bool
    @Binding var isActivityCollapsed: Bool

    private var effectiveSession: SessionData? {
        sessionStore.effectiveSession
    }

    private var state: LoroState {
        effectiveSession?.state ?? .idle
    }

    private var showIndicator: Bool {
        state.task == .working || state.task == .compacting || state.task == .waiting
    }

    private var tips: [EnglishTip] {
        effectiveSession?.englishTips ?? []
    }

    private var shouldShowSessionPicker: Bool {
        sessionStore.activeSessionCount >= 2 && !showingSessionActivity
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !showingSettings {
                    if shouldShowSessionPicker {
                        sessionPickerContent(geometry: geometry)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        activityContent(geometry: geometry)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }

                PanelSettingsView()
                    .frame(width: geometry.size.width)
                    .offset(x: showingSettings ? 0 : geometry.size.width)
                    .opacity(showingSettings ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSettings)
        .animation(.easeInOut(duration: 0.25), value: shouldShowSessionPicker)
    }

    @ViewBuilder
    private func sessionPickerContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isActivityCollapsed {
                Spacer()
                    .allowsHitTesting(false)
            } else {
                Spacer()
                    .frame(height: geometry.size.height * 0.3)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                if !isActivityCollapsed {
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
                }

                Spacer()

                UsageBarView(
                    usage: usageService.currentUsage,
                    isLoading: usageService.isLoading,
                    error: usageService.error,
                    onConnect: { ClaudeUsageService.shared.connectAndStartPolling() },
                    onRetry: { ClaudeUsageService.shared.retryNow() }
                )
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func activityContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isActivityCollapsed {
                Spacer()
                    .allowsHitTesting(false)
            } else {
                Spacer()
                    .frame(height: geometry.size.height * 0.3)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                if !tips.isEmpty {
                    Divider().background(Color.white.opacity(0.08))
                    tipsSection
                } else if !isActivityCollapsed {
                    Spacer()
                    emptyState
                }

                if !isActivityCollapsed {
                    Spacer()
                }

                if showIndicator && !isActivityCollapsed {
                    WorkingIndicatorView(state: state)
                }

                UsageBarView(
                    usage: usageService.currentUsage,
                    isLoading: usageService.isLoading,
                    error: usageService.error,
                    compact: isActivityCollapsed,
                    onConnect: { ClaudeUsageService.shared.connectAndStartPolling() },
                    onRetry: { ClaudeUsageService.shared.retryNow() }
                )
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isActivityCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("English Tips")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(TerminalColors.secondaryText)

                        Spacer()

                        if let session = effectiveSession {
                            let goodCount = session.englishTips.filter { $0.type == "good" }.count
                            let correctionCount = session.englishTips.filter { $0.type == "correction" }.count
                            HStack(spacing: 6) {
                                if goodCount > 0 {
                                    Text("\(goodCount) good")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(TerminalColors.green)
                                }
                                if correctionCount > 0 {
                                    Text("\(correctionCount) fix")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(TerminalColors.amber)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(tips) { tip in
                                    EnglishTipRowView(tip: tip)
                                        .id(tip.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .onAppear {
                            if let lastTip = tips.last {
                                proxy.scrollTo(lastTip.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: tips.last?.id) { _, newId in
                            if let id = newId {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var emptyState: some View {
        let hooksInstalled = HookInstaller.isInstalled()
        let title = hooksInstalled ? "Write in English!" : "Hooks not installed"
        let subtitle = hooksInstalled
            ? "Loro analyzes your English in Claude Code prompts"
            : "Open settings to set up Claude Code integration"

        return VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(TerminalColors.secondaryText)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - English Tip Row

struct EnglishTipRowView: View {
    let tip: EnglishTip

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon
            Text(tip.type == "good" ? "✅" : "📝")
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                // The prompt they wrote
                Text(tip.prompt)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(TerminalColors.dimmedText)
                    .lineLimit(1)

                // The tip/correction or "Good English!"
                if tip.type == "good" {
                    Text("Good English!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(TerminalColors.green)
                } else if let tipText = tip.tip {
                    Text(tipText)
                        .font(.system(size: 11))
                        .foregroundColor(TerminalColors.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Category badge
                if let category = tip.category {
                    Text(category)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(TerminalColors.secondaryText)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(3)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            tip.type == "good"
                ? TerminalColors.green.opacity(0.05)
                : TerminalColors.amber.opacity(0.05)
        )
        .cornerRadius(6)
    }
}

// MARK: - Supporting Views

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

    var color: Color {
        switch mode {
        case "Plan Mode": TerminalColors.planMode
        case "Accept Edits": TerminalColors.acceptEdits
        default: TerminalColors.secondaryText
        }
    }

    var body: some View {
        Text(mode)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
    }
}
