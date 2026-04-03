import AppKit

enum PeriquitoTask: String, CaseIterable {
    case idle, working, sleeping, compacting, waiting

    var animationFPS: Double {
        switch self {
        case .compacting: return 6.0
        case .sleeping: return 2.0
        case .idle: return 3.0
        case .waiting: return 3.0
        case .working: return 4.0
        }
    }

    var spritePrefix: String { rawValue }

    var bobDuration: Double {
        switch self {
        case .sleeping:   return 4.0
        case .idle, .waiting: return 1.5
        case .working:    return 0.4
        case .compacting: return 0.5
        }
    }

    var bobAmplitude: CGFloat {
        switch self {
        case .sleeping, .compacting: return 0
        case .idle:                  return 1.5
        case .waiting:               return 0.5
        case .working:               return 0.5
        }
    }

    var canWalk: Bool {
        switch self {
        case .sleeping, .compacting, .waiting:
            return false
        case .idle, .working:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .idle:       return "Idle"
        case .working:    return "Working..."
        case .sleeping:   return "Sleeping"
        case .compacting: return "Compacting..."
        case .waiting:    return "Waiting..."
        }
    }

    var walkFrequencyRange: ClosedRange<Double> {
        switch self {
        case .sleeping, .waiting: return 30.0...60.0
        case .idle:               return 8.0...15.0
        case .working:            return 5.0...12.0
        case .compacting:         return 15.0...25.0
        }
    }

}

enum PeriquitoEmotion: String, CaseIterable {
    case neutral, happy, sad, sob

    var swayAmplitude: Double {
        switch self {
        case .neutral: return 0.5
        case .happy:   return 1.0
        case .sad:     return 0.25
        case .sob:     return 0.15
        }
    }
}

struct PeriquitoState: Equatable {
    var task: PeriquitoTask
    var emotion: PeriquitoEmotion = .neutral

    /// Resolves the sprite sheet name with fallback chain: exact emotion -> sad (for sob) -> neutral.
    var spriteSheetName: String {
        let name = "\(task.spritePrefix)_\(emotion.rawValue)"
        if NSImage(named: name) != nil { return name }
        if emotion == .sob {
            let sadName = "\(task.spritePrefix)_sad"
            if NSImage(named: sadName) != nil { return sadName }
        }
        return "\(task.spritePrefix)_neutral"
    }
    /// Animation parameters vary per sprite (task + emotion combination)
    var animationFPS: Double {
        switch (task, emotion) {
        case (.idle, .happy):                     return 10.0
        case (.idle, .sad):                       return 6.0
        case (.idle, .sob):                       return 4.0
        case (.working, .happy):                  return 12.0
        case (.working, .sad):                    return 8.0
        case (.working, .sob):                    return 6.0
        case (.waiting, .happy):                  return 10.0
        case (.waiting, .sad):                    return 6.0
        case (.waiting, .sob):                    return 5.0
        case (.compacting, _):                    return 14.0
        case (.sleeping, _):                      return 6.0
        case (.idle, .neutral):                   return 8.0
        case (.working, .neutral):                return 10.0
        case (.waiting, .neutral):                return 8.0
        }
    }

    var frameCount: Int {
        // walk, mad, sleep sprites have 16 frames; blink, talk, jump, kiss have 8
        switch (task, emotion) {
        case (.idle, .happy):                     return 16  // walk
        case (.idle, .sad), (.idle, .sob):        return 16  // mad
        case (.working, .sad), (.working, .sob):  return 16  // mad
        case (.waiting, .sob):                    return 16  // mad
        case (.sleeping, _):                      return 16  // sleep
        default:                                  return 8   // blink, talk, jump
        }
    }

    var columns: Int { 4 }  // All new sprites use 4 columns

    var bobDuration: Double { task.bobDuration }
    var bobAmplitude: CGFloat {
        switch emotion {
        case .sob: return 0
        case .sad: return task.bobAmplitude * 0.5
        default:   return task.bobAmplitude
        }
    }
    var swayAmplitude: Double { emotion.swayAmplitude }
    var canWalk: Bool { emotion == .sob ? false : task.canWalk }
    var displayName: String { task.displayName }
    var walkFrequencyRange: ClosedRange<Double> { task.walkFrequencyRange }

    static let idle = PeriquitoState(task: .idle)
    static let working = PeriquitoState(task: .working)
    static let sleeping = PeriquitoState(task: .sleeping)
    static let compacting = PeriquitoState(task: .compacting)
    static let waiting = PeriquitoState(task: .waiting)
}
