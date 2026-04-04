import AppKit
import Testing
@testable import periquito

@MainActor
struct ScreenIdentifierTests {
    @Test("Matches the screen used to create the identifier")
    func matchesSourceScreen() throws {
        let screen = try #require(NSScreen.screens.first)
        let identifier = ScreenIdentifier(screen: screen)

        #expect(identifier.matches(screen))
    }

    @Test("ScreenSelector persists the chosen screen in injected settings storage")
    func selectorPersistsSelection() throws {
        let screen = try #require(NSScreen.screens.first)
        let store = MemorySettingsStore()

        let selector = ScreenSelector(settingsStore: store)
        selector.selectScreen(screen)

        let reloaded = ScreenSelector(settingsStore: store)

        #expect(reloaded.selectionMode == .specificScreen)
        #expect(reloaded.selectedScreen.map(ScreenIdentifier.init(screen:)) == ScreenIdentifier(screen: screen))
    }
}
