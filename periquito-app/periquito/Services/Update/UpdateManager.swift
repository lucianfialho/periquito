import Combine
import Sparkle

/// Update state published to UI
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case found(version: String, releaseNotes: String?)
    case downloading(progress: Double)
    case extracting(progress: Double)
    case readyToInstall(version: String)
    case installing
    case error(message: String)

    var isActive: Bool {
        switch self {
        case .idle, .upToDate, .error:
            return false
        default:
            return true
        }
    }
}

/// Observable update manager that bridges Sparkle to SwiftUI.
/// Called by NotchUserDriver to relay Sparkle lifecycle events,
/// and by the UI to trigger user-initiated actions.
class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    @Published var state: UpdateState = .idle
    @Published var hasUnseenUpdate: Bool = false
    private var hasSeenUpdateThisSession: Bool = false

    private var downloadedBytes: Int64 = 0
    private var expectedBytes: Int64 = 0
    private var currentVersion: String = ""

    private var installHandler: ((SPUUserUpdateChoice) -> Void)?
    private var cancellationHandler: (() -> Void)?
    private var resetTask: Task<Void, Never>?

    private var updater: SPUUpdater?

    func setUpdater(_ updater: SPUUpdater) {
        self.updater = updater
    }

    // MARK: - Public (UI actions)

    func checkForUpdates() {
        guard let updater, updater.canCheckForUpdates else { return }
        state = .checking
        updater.checkForUpdates()
    }

    func downloadAndInstall() {
        installHandler?(.install)
        installHandler = nil
    }

    func skipUpdate() {
        installHandler?(.skip)
        installHandler = nil
        state = .idle
        hasUnseenUpdate = false
    }

    func dismissUpdate() {
        installHandler?(.dismiss)
        installHandler = nil
        state = .idle
    }

    func cancelDownload() {
        cancellationHandler?()
        cancellationHandler = nil
        state = .idle
    }

    // MARK: - Internal (called by NotchUserDriver)

    func updateFound(
        version: String,
        releaseNotes: String?,
        installHandler: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        currentVersion = version
        self.installHandler = installHandler
        state = .found(version: version, releaseNotes: releaseNotes)

        if !hasSeenUpdateThisSession {
            hasUnseenUpdate = true
        }
    }

    func markUpdateSeen() {
        hasSeenUpdateThisSession = true
        hasUnseenUpdate = false
    }

    func downloadStarted(cancellation: @escaping () -> Void) {
        downloadedBytes = 0
        expectedBytes = 0
        cancellationHandler = cancellation
        state = .downloading(progress: 0)
    }

    func downloadExpectedLength(_ length: UInt64) {
        expectedBytes = Int64(length)
    }

    func downloadReceivedData(_ length: UInt64) {
        downloadedBytes += Int64(length)
        let progress = expectedBytes > 0
            ? Double(downloadedBytes) / Double(expectedBytes)
            : 0
        state = .downloading(progress: min(progress, 1.0))
    }

    func extractionStarted() {
        state = .extracting(progress: 0)
    }

    func extractionProgress(_ progress: Double) {
        state = .extracting(progress: progress)
    }

    func readyToInstall(installHandler: @escaping (SPUUserUpdateChoice) -> Void) {
        self.installHandler = installHandler
        state = .readyToInstall(version: currentVersion)
    }

    func installing() {
        state = .installing
    }

    func installed(relaunched: Bool) {
        state = .idle
    }

    func noUpdateFound() {
        state = .upToDate
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if case .upToDate = state {
                state = .idle
            }
        }
    }

    func updateError(_ message: String) {
        state = .error(message: message)
    }

    func sparkleDidDismiss() {
        installHandler?(.dismiss)
        installHandler = nil
        cancellationHandler = nil
        // Sparkle calls dismissUpdateInstallation() right after noUpdateFound(),
        // which would reset state before the 5-second "up to date" display timer expires.
        if case .upToDate = state { return }
        state = .idle
    }
}
