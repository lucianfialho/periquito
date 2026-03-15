import SwiftUI

struct StatsView: View {
    let stats: HistoryStats?
    let levelManager: LevelManager
    var quizManager: SpacedRepetitionManager = .shared
    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }

    private var evaluated: Int { stats?.totalEvaluated ?? 0 }
    private var hasData: Bool { evaluated > 0 }

    private var accuracyValue: Int { stats?.accuracy ?? 0 }
    private var accuracyProgress: Double {
        guard let acc = stats?.accuracy else { return 0 }
        return Double(acc) / 100.0
    }

    private var accuracyColor: Color {
        guard let acc = stats?.accuracy else { return TerminalColors.dimmedText }
        if acc >= 80 { return TerminalColors.green }
        if acc >= 50 { return TerminalColors.amber }
        return Color(red: 0.95, green: 0.4, blue: 0.35)
    }

    private var accuracyTrackColor: Color {
        accuracyColor.opacity(0.12)
    }

    var body: some View {
        if hasData {
            statsContent
        } else {
            emptyState
        }
    }

    // MARK: - Main Content

    private var statsContent: some View {
        VStack(spacing: 14) {
            // Level bar — compact, top of stats
            levelRow

            // Hero: accuracy ring + stat counters side by side
            HStack(spacing: 16) {
                accuracyRing
                statCounters
            }
            .padding(.horizontal, 2)

            // Accuracy hint for next level
            if let hint = accuracyHint {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 9))
                    Text(hint)
                        .font(.system(size: 9.5, weight: .medium))
                }
                .foregroundColor(TerminalColors.amber.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(TerminalColors.amber.opacity(0.06))
                .cornerRadius(6)
            }

            // Spaced repetition row
            if quizManager.items.count > 0 {
                reviewRow
            }

            // Decay warning
            if levelManager.lastDecayAmount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 9))
                    Text("-\(levelManager.lastDecayAmount) XP")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("(\(levelManager.lastDecayDays)d away)")
                        .font(.system(size: 9.5))
                }
                .foregroundColor(TerminalColors.amber.opacity(0.7))
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 2)
    }

    // MARK: - Accuracy Ring

    private var accuracyRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(accuracyTrackColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Progress arc
            Circle()
                .trim(from: 0, to: accuracyProgress)
                .stroke(accuracyColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: accuracyProgress)

            // Inner glow
            Circle()
                .fill(accuracyColor.opacity(0.04))

            // Value
            VStack(spacing: -1) {
                Text("\(accuracyValue)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accuracyColor)
                Text("%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(accuracyColor.opacity(0.6))
            }
        }
        .frame(width: 68, height: 68)
    }

    // MARK: - Stat Counters (vertical stack next to ring)

    private var statCounters: some View {
        VStack(alignment: .leading, spacing: 8) {
            statRow(
                icon: "text.bubble.fill",
                label: "Evaluated",
                value: evaluated,
                color: TerminalColors.secondaryText
            )
            statRow(
                icon: "checkmark.circle.fill",
                label: "Good",
                value: stats?.totalGood ?? 0,
                color: TerminalColors.green
            )
            statRow(
                icon: "pencil.circle.fill",
                label: "Corrections",
                value: stats?.totalCorrections ?? 0,
                color: TerminalColors.amber
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)

            Text("\(value)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 32, alignment: .trailing)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(TerminalColors.dimmedText)
        }
    }

    // MARK: - Level Row

    private var levelRow: some View {
        let level = levelManager.level
        let xp = levelManager.xp

        return HStack(spacing: 8) {
            if level == .phoenix {
                Text("\(level.emoji) \(level.name)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(TerminalColors.primaryText)
                Spacer()
                Text("MAX")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(TerminalColors.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TerminalColors.green.opacity(0.15))
                    .cornerRadius(4)
            } else if let next = level.nextLevel {
                Text("\(level.emoji) \(level.name)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(TerminalColors.primaryText)
                    .scaleEffect(levelManager.didLevelUp ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: levelManager.didLevelUp)

                xpProgressBar(current: xp, from: level.xpThreshold, to: next.xpThreshold)

                Text("\(xp)/\(next.xpThreshold)")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(TerminalColors.dimmedText)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private func xpProgressBar(current: Int, from: Int, to: Int) -> some View {
        let range = max(to - from, 1)
        let progress = min(max(Double(current - from) / Double(range), 0), 1)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(TerminalColors.green)
                    .frame(width: geo.size.width * progress)
                    .shadow(color: TerminalColors.green.opacity(0.3), radius: 3, x: 0, y: 0)
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 5)
    }

    // MARK: - Review Row

    private var reviewRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9))
                    .foregroundColor(quizManager.dueCount > 0 ? TerminalColors.amber : TerminalColors.dimmedText)
                Text("Due")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
                Text("\(quizManager.dueCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(quizManager.dueCount > 0 ? TerminalColors.amber : TerminalColors.green)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundColor(TerminalColors.green.opacity(0.6))
                Text("Mastered")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
                Text("\(quizManager.masteredCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(TerminalColors.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Hints

    private var accuracyHint: String? {
        guard let next = levelManager.level.nextLevel,
              let rolling = stats?.rollingAccuracy,
              rolling < next.minAccuracy else { return nil }
        return "\(next.minAccuracy)% accuracy needed for \(next.name) (at \(rolling)%)"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Write in English")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(TerminalColors.secondaryText)
            Text("to start tracking progress")
                .font(.system(size: 11))
                .foregroundColor(TerminalColors.dimmedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
