import SwiftUI

struct ChatTipView: View {
    let tip: EnglishTip
    var emotion: PeriquitoEmotion = .neutral

    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }

    private static let goodPhrases = [
        "Solid English.", "Reads naturally.", "Well put.", "Clean grammar.",
        "No issues here.", "Nailed it.", "Perfect.", "Nice one.",
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
        case .happy:
            TerminalColors.green.opacity(0.18)
        case .sad:
            TerminalColors.green.opacity(0.06)
        default:
            TerminalColors.green.opacity(0.12)
        }
    }

    private var correctionBubbleColor: Color {
        switch emotion {
        case .sob:
            Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.12)
        default:
            TerminalColors.amber.opacity(0.08)
        }
    }

    private var parsedParts: [(wrong: String, right: String, why: String)] {
        guard let tipText = tip.tip else {
            return []
        }

        let segments = tipText.components(separatedBy: "; ")
        var parts: [(wrong: String, right: String, why: String)] = []

        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

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
                if tip.type == .good {
                    goodBubble
                } else {
                    correctionBubbles
                }
            }

            Spacer()
        }
    }

    private var goodBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(goodMessage)
                .font(.system(size: fontSize.tipFont))
                .foregroundColor(emotion == .sad ? TerminalColors.green.opacity(0.7) : TerminalColors.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(goodBubbleColor)
                .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

            if let tipText = tip.tip, !tipText.isEmpty {
                Text(tipText)
                    .font(.system(size: fontSize.promptFont))
                    .foregroundColor(TerminalColors.dimmedText.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10, corners: [.topLeft, .topRight, .bottomRight])
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

    private var correctionBubbles: some View {
        let parts = parsedParts

        return VStack(alignment: .leading, spacing: 4) {
            if parts.isEmpty, let tipText = tip.tip {
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
