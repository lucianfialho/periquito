import Foundation

struct AppSettings {
    private static let notificationSoundKey = "notificationSound"
    private static let isMutedKey = "isMuted"
    private static let previousSoundKey = "previousNotificationSound"
    private static let isUsageEnabledKey = "isUsageEnabled"
    private static let fontSizeKey = "fontSize"

    static var isUsageEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: isUsageEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: isUsageEnabledKey) }
    }

    static var anthropicApiKey: String? {
        get { KeychainManager.getAnthropicApiKey() }
        set { KeychainManager.setAnthropicApiKey(newValue) }
    }

    static var notificationSound: NotificationSound {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: notificationSoundKey),
                  let sound = NotificationSound(rawValue: rawValue) else {
                return .purr
            }
            return sound
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: notificationSoundKey)
        }
    }

    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: isMutedKey) }
        set { UserDefaults.standard.set(newValue, forKey: isMutedKey) }
    }

    static func toggleMute() {
        if isMuted {
            notificationSound = previousSound ?? .purr
            isMuted = false
        } else {
            previousSound = notificationSound
            notificationSound = .none
            isMuted = true
        }
    }

    enum FontSize: String, CaseIterable {
        case small = "small"
        case regular = "regular"
        case large = "large"

        var tipFont: CGFloat {
            switch self {
            case .small: return 10
            case .regular: return 11
            case .large: return 13
            }
        }

        var promptFont: CGFloat {
            switch self {
            case .small: return 9
            case .regular: return 10
            case .large: return 12
            }
        }

        var label: String {
            switch self {
            case .small: return "S"
            case .regular: return "M"
            case .large: return "L"
            }
        }
    }

    static var fontSize: FontSize {
        get {
            guard let raw = UserDefaults.standard.string(forKey: fontSizeKey),
                  let size = FontSize(rawValue: raw) else {
                return .regular
            }
            return size
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: fontSizeKey)
        }
    }

    private static var previousSound: NotificationSound? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: previousSoundKey) else {
                return nil
            }
            return NotificationSound(rawValue: rawValue)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: previousSoundKey)
        }
    }
}
