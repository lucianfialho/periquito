import SwiftUI

@MainActor
struct ExpandedPanelView: View {
    @Bindable var viewModel: ExpandedPanelViewModel
    @Binding var showingSettings: Bool
    @Binding var isActivityCollapsed: Bool
    @State private var settingsViewModel = PanelSettingsViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !showingSettings {
                    activityContent(geometry: geometry)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                PanelSettingsView(viewModel: settingsViewModel)
                    .frame(width: geometry.size.width)
                    .offset(x: showingSettings ? 0 : geometry.size.width)
                    .opacity(showingSettings ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSettings)
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
                if isActivityCollapsed {
                    collapsedStatsRow
                } else {
                    Divider().background(Color.white.opacity(0.08))
                    tabBar
                    contentSection
                    Spacer()

                    if viewModel.showIndicator {
                        WorkingIndicatorView(state: viewModel.state)
                    }
                }
            }
            .padding(.horizontal, 12)
            .task { await viewModel.loadStats() }
            .onChange(of: viewModel.tips.count) { _, _ in
                Task { await viewModel.loadStats() }
            }
        }
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.selectedTab == .tips {
            if viewModel.quizManager.quizState != .idle {
                quizSection
            } else if !viewModel.tips.isEmpty {
                tipsSection
            } else {
                Spacer()
                emptyState
            }
        } else {
            StatsView(
                stats: viewModel.historyStats,
                levelManager: viewModel.levelManager,
                quizManager: viewModel.quizManager
            )
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectTab(tab)
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: viewModel.selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(viewModel.selectedTab == tab ? TerminalColors.primaryText : TerminalColors.dimmedText)

                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? TerminalColors.green : Color.clear)
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

    private var collapsedStatsRow: some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.historyStats.flatMap { $0.accuracy.map { "\($0)" } } ?? "--")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.collapsedAccuracyColor)
                Text("%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(viewModel.collapsedAccuracyColor.opacity(0.7))
            }

            if viewModel.showDelta {
                HStack(spacing: 2) {
                    Image(systemName: viewModel.accuracyDelta > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(abs(viewModel.accuracyDelta))%")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(viewModel.accuracyDelta > 0 ? TerminalColors.green : TerminalColors.amber)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            if let stats = viewModel.historyStats, stats.totalEvaluated > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 9))
                        .foregroundColor(TerminalColors.green.opacity(0.8))
                    Text("\(stats.totalGood)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(TerminalColors.green)
                }

                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 9))
                        .foregroundColor(TerminalColors.amber.opacity(0.8))
                    Text("\(stats.totalCorrections)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(TerminalColors.amber)
                }
            }

            Spacer()

            Text("\(viewModel.levelManager.level.emoji) \(viewModel.levelManager.level.name)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .padding(.horizontal, 4)
        .padding(.top, 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showDelta)
    }

    private var quizSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isActivityCollapsed {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(viewModel.tips.suffix(3)) { tip in
                            ChatTipView(tip: tip, emotion: viewModel.currentEmotion)
                        }

                        QuizBubbleView(
                            quizState: viewModel.quizManager.quizState,
                            options: viewModel.quizManager.currentOptions,
                            currentQuiz: viewModel.quizManager.currentQuiz,
                            correctAnswer: viewModel.quizManager.currentQuiz?.correctSentence ?? "",
                            onSubmit: { answer in
                                viewModel.quizManager.submitAnswer(answer)
                            },
                            onDismiss: {
                                viewModel.quizManager.dismissQuiz()
                            }
                        )
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isActivityCollapsed {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(viewModel.tips) { tip in
                                ChatTipView(tip: tip, emotion: viewModel.currentEmotion)
                                    .id(tip.id)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            if viewModel.isAnalyzing {
                                TypingIndicatorView()
                                    .id("typing")
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.tips.count)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: 200)
                    .onAppear {
                        if let lastTip = viewModel.tips.last {
                            proxy.scrollTo(lastTip.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.tips.count) { _, _ in
                        if let lastTip = viewModel.tips.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastTip.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isAnalyzing) { _, analyzing in
                        if analyzing {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(viewModel.emptyStateTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(TerminalColors.secondaryText)
            Text(viewModel.emptyStateSubtitle)
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .frame(maxWidth: .infinity)
    }
}
