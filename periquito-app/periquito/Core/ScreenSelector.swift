import AppKit

enum ScreenSelectionMode: String, Codable {
    case automatic
    case specificScreen
}

struct ScreenIdentifier: Codable, Equatable, Hashable {
    let displayID: CGDirectDisplayID?
    let localizedName: String

    private static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    init(screen: NSScreen) {
        self.displayID = screen.deviceDescription[Self.screenNumberKey] as? CGDirectDisplayID
        self.localizedName = screen.localizedName
    }

    func matches(_ screen: NSScreen) -> Bool {
        let screenNumber = screen.deviceDescription[Self.screenNumberKey] as? CGDirectDisplayID

        if let savedID = displayID, let screenNumber, savedID == screenNumber {
            return true
        }
        return localizedName == screen.localizedName
    }
}

@MainActor
@Observable
final class ScreenSelector {
    static let shared = ScreenSelector()

    private(set) var availableScreens: [NSScreen] = []
    private(set) var selectedScreen: NSScreen?
    var selectionMode: ScreenSelectionMode = .automatic
    var isPickerExpanded = false

    private let modeKey = "screenSelectionMode"
    private let screenIdentifierKey = "selectedScreenIdentifier"
    private let settingsStore: SettingsStoring
    private var savedIdentifier: ScreenIdentifier?

    init(settingsStore: (any SettingsStoring)? = nil) {
        self.settingsStore = settingsStore ?? UserDefaultsSettingsStore()
        loadPreferences()
        refreshScreens()
    }

    func refreshScreens() {
        availableScreens = NSScreen.screens
        selectedScreen = resolveSelectedScreen()
    }

    func selectScreen(_ screen: NSScreen) {
        selectionMode = .specificScreen
        savedIdentifier = ScreenIdentifier(screen: screen)
        selectedScreen = screen
        savePreferences()
    }

    func selectAutomatic() {
        selectionMode = .automatic
        savedIdentifier = nil
        selectedScreen = resolveSelectedScreen()
        savePreferences()
    }

    func isSelected(_ screen: NSScreen) -> Bool {
        guard let selected = selectedScreen else { return false }
        return ScreenIdentifier(screen: screen) == ScreenIdentifier(screen: selected)
    }

    private func resolveSelectedScreen() -> NSScreen? {
        switch selectionMode {
        case .automatic:
            return NSScreen.builtInOrMain

        case .specificScreen:
            if let identifier = savedIdentifier,
               let match = availableScreens.first(where: { identifier.matches($0) }) {
                return match
            }
            return NSScreen.builtInOrMain
        }
    }

    private func loadPreferences() {
        if let modeString = settingsStore.string(forKey: modeKey),
           let mode = ScreenSelectionMode(rawValue: modeString) {
            selectionMode = mode
        }

        if let data = settingsStore.data(forKey: screenIdentifierKey),
           let identifier = try? JSONDecoder().decode(ScreenIdentifier.self, from: data) {
            savedIdentifier = identifier
        }
    }

    private func savePreferences() {
        settingsStore.set(selectionMode.rawValue, forKey: modeKey)

        if let identifier = savedIdentifier,
           let data = try? JSONEncoder().encode(identifier) {
            settingsStore.set(data, forKey: screenIdentifierKey)
        } else {
            settingsStore.removeObject(forKey: screenIdentifierKey)
        }
    }
}
