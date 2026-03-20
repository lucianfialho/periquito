import SwiftUI

struct QuizBubbleView: View {
    let quizState: QuizState
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @State private var selectedAnswer: String?
    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch quizState {
            case .asking(let item):
                questionBubble(item: item)
            case .evaluating:
                questionLoading
            case .result(let correct, let explanation):
                resultBubble(correct: correct, explanation: explanation)
            case .idle:
                EmptyView()
            }
        }
    }

    // MARK: - Question (multiple choice)

    private func questionBubble(item: QuizItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("🦜")
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 8) {
                Text("Which is correct?")
                    .font(.system(size: fontSize.tipFont, weight: .semibold))
                    .foregroundColor(TerminalColors.amber)

                // Show explanation as context
                if !item.explanation.isEmpty {
                    Text(item.explanation)
                        .font(.system(size: fontSize.promptFont))
                        .foregroundColor(TerminalColors.dimmedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Multiple choice buttons — wrong vs correct (shuffled)
                let options = Self.shuffledOptions(item: item)
                VStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selectedAnswer = option
                            onSubmit(option)
                        }) {
                            Text(option)
                                .font(.system(size: fontSize.tipFont, weight: .medium))
                                .foregroundColor(TerminalColors.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Dismiss
                Button(action: onDismiss) {
                    Text("Skip")
                        .font(.system(size: fontSize.promptFont))
                        .foregroundColor(TerminalColors.dimmedText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(TerminalColors.amber.opacity(0.06))
            .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

            Spacer()
        }
    }

    private static func shuffledOptions(item: QuizItem) -> [String] {
        // Take just the core part (before any " / " alternatives)
        let correct = item.correctSentence.components(separatedBy: " / ").first ?? item.correctSentence
        let wrong = item.incorrectSentence
        return [correct, wrong].shuffled()
    }

    // MARK: - Loading

    private var questionLoading: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("🦜")
                .font(.system(size: 14))
            TypingIndicatorView()
        }
    }

    // MARK: - Result

    private static let correctPhrases = [
        "Nailed it!", "You remembered!", "Great recall!",
        "Well done!", "Sharp memory!", "Exactly right!",
        "Perfect!", "You've got this!", "Solid answer!",
    ]

    private func resultBubble(correct: Bool, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text("🦜")
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(correct ? TerminalColors.green : TerminalColors.red)
                        Text(correct ? (Self.correctPhrases.randomElement() ?? "Correct!") : "Not quite...")
                            .font(.system(size: fontSize.tipFont, weight: .semibold))
                            .foregroundColor(correct ? TerminalColors.green : TerminalColors.red)
                    }

                    // Show the correct answer and explanation
                    let parts = explanation.components(separatedBy: " — ")
                    let sentence = parts.first ?? explanation
                    let tip = parts.count > 1 ? parts.dropFirst().joined(separator: " — ") : nil

                    Text(sentence)
                        .font(.system(size: fontSize.tipFont, weight: .medium))
                        .foregroundColor(correct ? TerminalColors.green : TerminalColors.secondaryText)

                    if let tip, !tip.isEmpty {
                        Text(tip)
                            .font(.system(size: fontSize.promptFont))
                            .foregroundColor(TerminalColors.dimmedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let quiz = currentQuiz {
                        progressBadge(quiz: quiz)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background((correct ? TerminalColors.green : TerminalColors.red).opacity(0.08))
                .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

                Spacer()
            }

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: fontSize.promptFont, weight: .medium))
                        .foregroundColor(TerminalColors.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(TerminalColors.green.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var currentQuiz: QuizItem? {
        if case .asking(let item) = quizState { return item }
        return SpacedRepetitionManager.shared.currentQuiz
    }

    private func progressBadge(quiz: QuizItem) -> some View {
        let streak = quiz.correctCount
        let box = quiz.box

        return HStack(spacing: 8) {
            if streak > 1 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text("\(streak) in a row")
                        .font(.system(size: fontSize.promptFont - 1, weight: .medium))
                }
                .foregroundColor(TerminalColors.amber)
            }

            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= box ? TerminalColors.green : Color.white.opacity(0.15))
                        .frame(width: 5, height: 5)
                }
            }

            if box >= 5 {
                Text("Mastered!")
                    .font(.system(size: fontSize.promptFont - 1, weight: .semibold))
                    .foregroundColor(TerminalColors.green)
            }
        }
    }
}
