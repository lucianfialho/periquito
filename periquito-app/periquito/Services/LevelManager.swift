import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.ruban.periquito", category: "LevelManager")

@MainActor
@Observable
final class LevelManager {
    static let shared = LevelManager()

    var xp: Int = 0
    var level: ParrotLevel = .egg
    var lastActiveDate: Date?
    var inactivityEmotion: PeriquitoEmotion?
    var lastDecayAmount: Int = 0
    var lastDecayDays: Int = 0
    private(set) var didLevelUp: Bool = false

    private static let levelFile: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("level.json")
    }()

    private init() {
        load()
    }

    // MARK: - XP

    func awardXP(for type: String, rollingAccuracy: Int) {
        let points: Int
        switch type {
        case "good": points = 10
        case "correction": points = 5
        default: return
        }

        xp += points
        lastActiveDate = Date()
        inactivityEmotion = nil
        lastDecayAmount = 0
        lastDecayDays = 0

        checkLevelUp(accuracy: rollingAccuracy)
        save()

        logger.info("Awarded \(points) XP → total \(self.xp), level \(self.level.name)")
    }

    func checkLevelUp(accuracy: Int) {
        let newLevel = ParrotLevel.levelFor(xp: xp, accuracy: accuracy, currentLevel: level)
        if newLevel.rawValue > level.rawValue {
            didLevelUp = true
            level = newLevel
            // Play glass sound on level up
            if let sound = NSSound(named: NSSound.Name("Glass")) {
                sound.play()
            }
            logger.info("Level up! Now \(self.level.name)")
        }
    }

    func clearLevelUpFlag() {
        didLevelUp = false
    }

    // MARK: - Decay

    @discardableResult
    func applyDecay() -> Int {
        guard let lastActive = lastActiveDate else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastActive)
        let daysMissed = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        // Only decay if >1 day gap (allow normal overnight gaps)
        guard daysMissed > 1 else {
            inactivityEmotion = nil
            return 0
        }

        let decayDays = daysMissed - 1 // first day is not penalized
        let floor = level.xpThreshold
        let previousXP = xp
        let decayed = Int(Double(xp) * pow(0.95, Double(decayDays)))
        xp = max(floor, decayed)

        lastDecayAmount = previousXP - xp
        lastDecayDays = daysMissed

        // UX: 2 days → sad, 5+ days → sob
        if daysMissed >= 5 {
            inactivityEmotion = .sob
        } else if daysMissed >= 2 {
            inactivityEmotion = .sad
        } else {
            inactivityEmotion = nil
        }

        save()
        logger.info("Applied decay: \(decayDays) days, \(previousXP) → \(self.xp) XP, emotion: \(self.inactivityEmotion?.rawValue ?? "none")")
        return daysMissed
    }

    var daysInactive: Int {
        guard let lastActive = lastActiveDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastActive)
        return calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
    }

    // MARK: - Persistence

    private struct LevelData: Codable {
        var xp: Int
        var level: ParrotLevel
        var lastActiveDate: String?
    }

    private func save() {
        let dateString: String?
        if let date = lastActiveDate {
            dateString = ISO8601DateFormatter().string(from: date)
        } else {
            dateString = nil
        }

        let data = LevelData(xp: xp, level: level, lastActiveDate: dateString)
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: Self.levelFile)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.levelFile.path),
              let data = try? Data(contentsOf: Self.levelFile),
              let levelData = try? JSONDecoder().decode(LevelData.self, from: data) else {
            logger.info("No level file found, starting fresh")
            return
        }

        xp = levelData.xp
        level = levelData.level
        if let dateStr = levelData.lastActiveDate {
            lastActiveDate = ISO8601DateFormatter().date(from: dateStr)
        }

        logger.info("Loaded level: \(self.level.name), XP: \(self.xp)")
    }
}
