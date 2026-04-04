import Testing
@testable import periquito

@MainActor
@Suite(.serialized)
struct AppSettingsTests {
    @Test("toggleMute stores the previous sound and restores it on unmute")
    func toggleMuteRoundTrip() {
        let store = MemorySettingsStore()
        let originalStore = AppSettings.settingsStore
        AppSettings.settingsStore = store
        defer { AppSettings.settingsStore = originalStore }

        AppSettings.notificationSound = .hero
        AppSettings.isMuted = false

        AppSettings.toggleMute()

        #expect(AppSettings.isMuted)
        #expect(AppSettings.notificationSound == .none)

        AppSettings.toggleMute()

        #expect(!AppSettings.isMuted)
        #expect(AppSettings.notificationSound == .hero)
    }
}
