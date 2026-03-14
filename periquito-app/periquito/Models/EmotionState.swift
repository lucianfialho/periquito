import Foundation
import os.log

private let logger = Logger(subsystem: "com.ruban.periquito", category: "EmotionState")

@MainActor
@Observable
final class EmotionState {
    private(set) var currentEmotion: PeriquitoEmotion = .neutral
    private(set) var scores: [PeriquitoEmotion: Double] = [
        .happy: 0.0,
        .sad: 0.0
    ]

    static let sadThreshold = 0.45
    static let happyThreshold = 0.6
    static let sobEscalationThreshold = 0.9
    static let intensityDampen = 0.5
    static let decayRate = 0.92
    static let interEmotionDecay = 0.9
    static let neutralCounterDecay = 0.85
    static let decayInterval: Duration = .seconds(60)

    private var scoresDescription: String {
        scores
            .sorted(by: { $0.key.rawValue < $1.key.rawValue })
            .map { "\($0.key.rawValue): \(String(format: "%.2f", $0.value))" }
            .joined(separator: ", ")
    }

    init() {}

    func recordEmotion(_ rawEmotion: String, intensity: Double, prompt: String) {
        let emotion = PeriquitoEmotion(rawValue: rawEmotion)

        if let emotion, emotion != .neutral {
            let dampened = intensity * Self.intensityDampen
            scores[emotion, default: 0.0] = min(scores[emotion, default: 0.0] + dampened, 1.0)
            for key in scores.keys where key != emotion {
                scores[key, default: 0.0] *= Self.interEmotionDecay
            }
        } else {
            // Neutral or unknown: actively counter all non-neutral scores
            for key in scores.keys {
                scores[key, default: 0.0] *= Self.neutralCounterDecay
            }
        }

        updateCurrentEmotion()

        let truncatedPrompt = String(prompt.prefix(60))
        logger.info("[Emotion] \"\(truncatedPrompt, privacy: .public)\" → detected: \(rawEmotion, privacy: .public) (\(String(format: "%.2f", intensity), privacy: .public)) → cumulative: {\(self.scoresDescription, privacy: .public)}")
    }

    func decayAll() {
        var anyChanged = false
        for key in scores.keys {
            let old = scores[key, default: 0.0]
            let new = old * Self.decayRate
            scores[key] = new < 0.01 ? 0.0 : new
            if scores[key] != old { anyChanged = true }
        }

        if anyChanged {
            updateCurrentEmotion()
            logger.debug("[Emotion] decay → {\(self.scoresDescription, privacy: .public)} → current: \(self.currentEmotion.rawValue, privacy: .public)")
        }
    }

    private func updateCurrentEmotion() {
        let best = scores.max(by: { $0.value < $1.value })

        if let best {
            let threshold = best.key == .sad ? Self.sadThreshold : Self.happyThreshold
            if best.value >= threshold {
                if best.key == .sad && best.value >= Self.sobEscalationThreshold {
                    currentEmotion = .sob
                } else {
                    currentEmotion = best.key
                }
            } else {
                currentEmotion = .neutral
            }
        } else {
            currentEmotion = .neutral
        }
    }
}
