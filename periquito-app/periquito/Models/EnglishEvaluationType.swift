import Foundation

nonisolated enum EnglishEvaluationType: Codable, Equatable, Hashable, Sendable {
    case good
    case correction
    case skip
    case other(String)

    init(rawValue: String) {
        switch rawValue {
        case "good":
            self = .good
        case "correction":
            self = .correction
        case "skip":
            self = .skip
        default:
            self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .good:
            "good"
        case .correction:
            "correction"
        case .skip:
            "skip"
        case .other(let value):
            value
        }
    }

    var awardsXP: Bool {
        switch self {
        case .good, .correction:
            true
        case .skip, .other:
            false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = EnglishEvaluationType(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
