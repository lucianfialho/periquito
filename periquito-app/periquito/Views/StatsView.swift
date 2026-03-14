import SwiftUI

struct StatsView: View {
    let stats: HistoryStats?
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
        }
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }

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
