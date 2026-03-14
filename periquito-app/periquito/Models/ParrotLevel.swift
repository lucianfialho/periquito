import Foundation

enum ParrotLevel: Int, CaseIterable, Codable, Sendable {
    case egg = 1
    case chick = 2
    case parrot = 3
    case macaw = 4
    case phoenix = 5

    var name: String {
        switch self {
        case .egg: "Egg"
        case .chick: "Chick"
        case .parrot: "Parrot"
        case .macaw: "Macaw"
        case .phoenix: "Phoenix"
        }
    }

    var emoji: String {
        switch self {
        case .egg: "🥚"
        case .chick: "🐥"
        case .parrot: "🦜"
        case .macaw: "🦚"
        case .phoenix: "🔥"
        }
    }

    var xpThreshold: Int {
        switch self {
        case .egg: 0
        case .chick: 100
        case .parrot: 500
        case .macaw: 2000
        case .phoenix: 5000
        }
    }

    var minAccuracy: Int {
        switch self {
        case .egg: 0
        case .chick: 30
        case .parrot: 50
        case .macaw: 70
        case .phoenix: 85
        }
    }

    var nextLevel: ParrotLevel? {
        ParrotLevel(rawValue: rawValue + 1)
    }

    /// Returns the highest level the user qualifies for, never below currentLevel.
    static func levelFor(xp: Int, accuracy: Int, currentLevel: ParrotLevel) -> ParrotLevel {
        var best = currentLevel
        for level in Self.allCases.reversed() {
            if level.rawValue <= currentLevel.rawValue { break }
            if xp >= level.xpThreshold && accuracy >= level.minAccuracy {
                best = level
                break
            }
        }
        return best
    }
}
