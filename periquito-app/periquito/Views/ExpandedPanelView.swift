import SwiftUI

private enum PanelTab: String, CaseIterable {
    case tips = "Tips"
    case stats = "Stats"
}

struct ExpandedPanelView: View {
    let sessionStore: SessionStore
    @Binding var showingSettings: Bool
    @Binding var showingSessionActivity: Bool
    @Binding var isActivityCollapsed: Bool
    @State private var selectedTab: PanelTab = .tips
    @State private var historyStats: HistoryStats?

    private var effectiveSession: SessionData? {
        sessionStore.effectiveSession
    }

    private var state: PeriquitoState {
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
                if !isActivityCollapsed {
                    Divider().background(Color.white.opacity(0.08))
                    tabBar
                }

                if selectedTab == .tips {
                    if !tips.isEmpty {
                        tipsSection
                    } else if !isActivityCollapsed {
                        Spacer()
                        emptyState
                    }
                } else {
                    if !isActivityCollapsed {
                        StatsView(stats: historyStats, levelManager: LevelManager.shared)
                    }
                }

                if !isActivityCollapsed {
                    Spacer()
                }

                if showIndicator && !isActivityCollapsed {
                    WorkingIndicatorView(state: state)
                }
            }
            .padding(.horizontal, 12)
            .task { await loadStats() }
            .onChange(of: tips.count) { _, _ in
                Task { await loadStats() }
            }
        }
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var isAnalyzing: Bool {
        effectiveSession?.isAnalyzingEnglish ?? false
    }

    private var currentEmotion: PeriquitoEmotion {
        effectiveSession?.state.emotion ?? .neutral
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? TerminalColors.primaryText : TerminalColors.dimmedText)

                        Rectangle()
                            .fill(selectedTab == tab ? TerminalColors.green : Color.clear)
                            .frame(height: 1.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }

    private func loadStats() async {
        historyStats = await HistoryStatsLoader.load()
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isActivityCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(tips) { tip in
                                    ChatTipView(tip: tip, emotion: currentEmotion)
                                        .id(tip.id)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }

                                if isAnalyzing {
                                    TypingIndicatorView()
                                        .id("typing")
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tips.count)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: 200)
                        .onAppear {
                            if let lastTip = tips.last {
                                proxy.scrollTo(lastTip.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: tips.count) { _, _ in
                            if let lastTip = tips.last {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(lastTip.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isAnalyzing) { _, analyzing in
                            if analyzing {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("typing", anchor: .bottom)
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
            ? "Periquito analyzes your English in Claude Code prompts"
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

// MARK: - Chat-style Tip View

struct ChatTipView: View {
    let tip: EnglishTip
    var emotion: PeriquitoEmotion = .neutral
    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }

    private static let goodPhrases = [
        "Solid English.", "Reads naturally.", "Well put.", "Clean grammar.",
        "No issues here.", "Nailed it.", "Perfect.", "Nice one."
    ]

    private var goodMessage: String {
        if emotion == .sad {
            return "Better! Keep going."
        }
        let index = abs(tip.id.hashValue) % Self.goodPhrases.count
        return Self.goodPhrases[index]
    }

    private var goodBubbleColor: Color {
        switch emotion {
        case .happy: return TerminalColors.green.opacity(0.18)
        case .sad: return TerminalColors.green.opacity(0.06)
        default: return TerminalColors.green.opacity(0.12)
        }
    }

    private var correctionBubbleColor: Color {
        switch emotion {
        case .sob: return Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.12)
        default: return TerminalColors.amber.opacity(0.08)
        }
    }

    private var parsedParts: [(wrong: String, right: String, why: String)] {
        guard let tipText = tip.tip else { return [] }
        // Split by ";" or by multiple ❌ markers for multi-correction tips
        let segments = tipText.components(separatedBy: "; ")
        var parts: [(wrong: String, right: String, why: String)] = []

        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Try to parse "❌ X → ✅ Y — Z" format
            if let arrowRange = trimmed.range(of: " → ") {
                let wrongPart = String(trimmed[trimmed.startIndex..<arrowRange.lowerBound])
                    .replacingOccurrences(of: "❌ ", with: "")
                    .replacingOccurrences(of: "❌", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let afterArrow = String(trimmed[arrowRange.upperBound...])

                if let dashRange = afterArrow.range(of: " — ") {
                    let rightPart = String(afterArrow[afterArrow.startIndex..<dashRange.lowerBound])
                        .replacingOccurrences(of: "✅ ", with: "")
                        .replacingOccurrences(of: "✅", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    let whyPart = String(afterArrow[dashRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    parts.append((wrong: wrongPart, right: rightPart, why: whyPart))
                } else {
                    let rightPart = afterArrow
                        .replacingOccurrences(of: "✅ ", with: "")
                        .replacingOccurrences(of: "✅", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    parts.append((wrong: wrongPart, right: rightPart, why: ""))
                }
            } else {
                parts.append((wrong: "", right: "", why: trimmed))
            }
        }
        return parts
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("🦜")
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 0) {
                if tip.type == "good" {
                    goodBubble
                } else {
                    correctionBubbles
                }
            }

            Spacer()
        }
    }

    private var goodBubble: some View {
        Text(goodMessage)
            .font(.system(size: fontSize.tipFont))
            .foregroundColor(emotion == .sad ? TerminalColors.green.opacity(0.7) : TerminalColors.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(goodBubbleColor)
            .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])
    }

    private var correctionBubbles: some View {
        let parts = parsedParts

        return VStack(alignment: .leading, spacing: 4) {
            if parts.isEmpty, let tipText = tip.tip {
                // Fallback: show raw text in a bubble
                Text(tipText)
                    .font(.system(size: fontSize.tipFont))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(TerminalColors.amber.opacity(0.12))
                    .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])
            } else {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    VStack(alignment: .leading, spacing: 4) {
                        if !part.wrong.isEmpty {
                            HStack(spacing: 4) {
                                Text(part.wrong)
                                    .font(.system(size: fontSize.tipFont))
                                    .strikethrough()
                                    .foregroundColor(TerminalColors.red.opacity(0.8))
                                Text("→")
                                    .font(.system(size: fontSize.tipFont))
                                    .foregroundColor(TerminalColors.dimmedText)
                                Text(part.right)
                                    .font(.system(size: fontSize.tipFont, weight: .medium))
                                    .foregroundColor(TerminalColors.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(correctionBubbleColor)
                            .cornerRadius(10, corners: [.topLeft, .topRight, .bottomRight])
                        }

                        if !part.why.isEmpty {
                            Text(part.why)
                                .font(.system(size: fontSize.promptFont))
                                .foregroundColor(TerminalColors.dimmedText.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 4)
                        }
                    }
                }
            }

            if let category = tip.category {
                Text(category)
                    .font(.system(size: fontSize.promptFont - 1, weight: .medium))
                    .foregroundColor(TerminalColors.dimmedText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
                    .padding(.leading, 4)
            }
        }
    }
}

// Helper for selective corner radius (macOS-compatible)
struct Corner: OptionSet {
    let rawValue: Int
    static let topLeft = Corner(rawValue: 1 << 0)
    static let topRight = Corner(rawValue: 1 << 1)
    static let bottomLeft = Corner(rawValue: 1 << 2)
    static let bottomRight = Corner(rawValue: 1 << 3)
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: Corner) -> some View {
        clipShape(RoundedCorners(radius: radius, corners: corners))
    }
}

struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: Corner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 { path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 { path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 { path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 { path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("🦜")
                .font(.system(size: 14))

            TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
                let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.4) % 3
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        let distance = min(abs(i - phase), 3 - abs(i - phase))
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 5, height: 5)
                            .opacity(distance == 0 ? 1.0 : (distance == 1 ? 0.5 : 0.2))
                            .animation(.easeInOut(duration: 0.3), value: phase)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

            Spacer()
        }
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
