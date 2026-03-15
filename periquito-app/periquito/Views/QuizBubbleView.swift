import SwiftUI

struct QuizBubbleView: View {
    let quizState: QuizState
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @State private var userAnswer = ""
    @FocusState private var isInputFocused: Bool
    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch quizState {
            case .asking(let item):
                questionBubble(item: item)
                answerInput
            case .evaluating:
                questionLoading
            case .result(let correct, let explanation):
                resultBubble(correct: correct, explanation: explanation)
            case .idle:
                EmptyView()
            }
        }
    }

    // MARK: - Question

    private func questionBubble(item: QuizItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("🦜")
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text("Quick review!")
                    .font(.system(size: fontSize.tipFont, weight: .semibold))
                    .foregroundColor(TerminalColors.amber)

                Text("How would you correct this?")
                    .font(.system(size: fontSize.tipFont))
                    .foregroundColor(TerminalColors.secondaryText)

                Text(item.incorrectSentence)
                    .font(.system(size: fontSize.tipFont + 1, weight: .medium))
                    .foregroundColor(TerminalColors.red.opacity(0.9))
                    .italic()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(TerminalColors.red.opacity(0.08))
                    .cornerRadius(8)

                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 8))
                    Text(item.category)
                        .font(.system(size: fontSize.promptFont - 1, weight: .medium))
                }
                .foregroundColor(TerminalColors.dimmedText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(TerminalColors.amber.opacity(0.06))
            .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

            Spacer()
        }
    }

    // MARK: - Answer Input

    private var answerInput: some View {
        HStack(spacing: 8) {
            Text("You:")
                .font(.system(size: fontSize.promptFont, weight: .medium))
                .foregroundColor(TerminalColors.dimmedText)

            TextField("Type the correct sentence...", text: $userAnswer)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize.tipFont))
                .foregroundColor(TerminalColors.primaryText)
                .focused($isInputFocused)
                .onSubmit {
                    guard !userAnswer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onSubmit(userAnswer)
                    userAnswer = ""
                }

            Button(action: {
                guard !userAnswer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                onSubmit(userAnswer)
                userAnswer = ""
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(userAnswer.isEmpty ? TerminalColors.dimmedText : TerminalColors.green)
            }
            .buttonStyle(.plain)
            .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(TerminalColors.dimmedText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .onAppear { isInputFocused = true }
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

    private func resultBubble(correct: Bool, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text("🦜")
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(correct ? TerminalColors.green : TerminalColors.red)
                        Text(correct ? "Correct!" : "Not quite...")
                            .font(.system(size: fontSize.tipFont, weight: .semibold))
                            .foregroundColor(correct ? TerminalColors.green : TerminalColors.red)
                    }

                    Text(explanation)
                        .font(.system(size: fontSize.tipFont))
                        .foregroundColor(correct ? TerminalColors.green.opacity(0.8) : TerminalColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !correct {
                        Text("This will come back for review soon.")
                            .font(.system(size: fontSize.promptFont))
                            .foregroundColor(TerminalColors.dimmedText)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background((correct ? TerminalColors.green : TerminalColors.red).opacity(0.08))
                .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

                Spacer()
            }

            // Dismiss button
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
}
