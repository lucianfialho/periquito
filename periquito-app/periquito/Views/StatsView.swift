import SwiftUI

struct StatsView: View {
    let stats: HistoryStats?
    let levelManager: LevelManager
    var quizManager: SpacedRepetitionManager = .shared
    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }

    private var evaluated: Int { stats?.totalEvaluated ?? 0 }
    private var hasData: Bool { evaluated > 0 }

    private var accuracyColor: Color {
        guard let acc = stats?.accuracy else { return TerminalColors.dimmedText }
        if acc >= 80 { return TerminalColors.green }
        if acc >= 50 { return TerminalColors.amber }
        return TerminalColors.red
    }

    var body: some View {
        if hasData {
            statsContent
        } else {
            emptyState
        }
    }

    private var statsContent: some View {
        VStack(spacing: 16) {
            // Level row (single line: emoji + name + bar + XP)
            levelRow
                .padding(.bottom, 2)

            // Accuracy hero
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if let acc = stats?.accuracy {
                        Text("\(acc)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(accuracyColor)
                        Text("%")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(accuracyColor.opacity(0.7))
                    } else {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(TerminalColors.dimmedText)
                    }
                }

                Text("accuracy")
                    .font(.system(size: fontSize.promptFont))
                    .foregroundColor(TerminalColors.dimmedText)
            }
            .frame(maxWidth: .infinity)

            // Stat cards row
            HStack(spacing: 12) {
                statCard(
                    label: "Evaluated",
                    value: "\(evaluated)",
                    color: TerminalColors.secondaryText
                )
                statCard(
                    label: "Good",
                    value: "\(stats?.totalGood ?? 0)",
                    color: TerminalColors.green
                )
                statCard(
                    label: "Corrections",
                    value: "\(stats?.totalCorrections ?? 0)",
                    color: TerminalColors.amber
                )
            }

            // Accuracy hint for next level
            if let hint = accuracyHint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.amber)
            }

            // Spaced repetition stats
            if quizManager.items.count > 0 {
                HStack(spacing: 12) {
                    statCard(
                        label: "Due Reviews",
                        value: "\(quizManager.dueCount)",
                        color: quizManager.dueCount > 0 ? TerminalColors.amber : TerminalColors.green
                    )
                    statCard(
                        label: "Mastered",
                        value: "\(quizManager.masteredCount)",
                        color: TerminalColors.green
                    )
                }
            }

            // Decay message (shown once per session)
            if levelManager.lastDecayAmount > 0 {
                Text("-\(levelManager.lastDecayAmount) XP  (\(levelManager.lastDecayDays) days missed)")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.amber)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    // MARK: - Level Row

    private var levelRow: some View {
        let level = levelManager.level
        let xp = levelManager.xp

        return VStack(alignment: .leading, spacing: 4) {
            if level == .phoenix {
                // Max level
                HStack {
                    Text("\(level.emoji) \(level.name)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TerminalColors.primaryText)
                        .scaleEffect(levelManager.didLevelUp ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: levelManager.didLevelUp)
                    Spacer()
                    Text("Max Level")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(TerminalColors.green)
                }
            } else if let next = level.nextLevel {
                HStack(spacing: 8) {
                    Text("\(level.emoji) \(level.name)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TerminalColors.primaryText)
                        .scaleEffect(levelManager.didLevelUp ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: levelManager.didLevelUp)

                    xpProgressBar(current: xp, from: level.xpThreshold, to: next.xpThreshold)

                    Text("\(xp) / \(next.xpThreshold)")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.dimmedText)
                        .fixedSize()
                }
            }
        }
    }

    private func xpProgressBar(current: Int, from: Int, to: Int) -> some View {
        let range = max(to - from, 1)
        let progress = min(max(Double(current - from) / Double(range), 0), 1)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(TerminalColors.green)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 6)
    }

    private var accuracyHint: String? {
        guard let next = levelManager.level.nextLevel,
              let rolling = stats?.rollingAccuracy,
              rolling < next.minAccuracy else { return nil }
        return "Need \(next.minAccuracy)% accuracy (currently \(rolling)%)"
    }

    // MARK: - Stat Cards

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: fontSize.promptFont - 1))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(TerminalColors.subtleBackground)
        .cornerRadius(8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Start writing in English")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(TerminalColors.secondaryText)
            Text("to see your progress!")
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
