import Foundation
import os.log

private let fileWatcherLogger = Logger(subsystem: "com.lucianfialho.periquito", category: "SessionFileWatcher")

@MainActor
final class SessionFileWatcher {
    private var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]

    func startWatching(
        sessionId: String,
        cwd: String,
        onChange: @escaping @MainActor () -> Void
    ) {
        stopWatching(sessionId: sessionId)

        let sessionFile = ConversationParser.sessionFilePath(sessionId: sessionId, cwd: cwd)
        let descriptor = open(sessionFile, O_EVTONLY)

        guard descriptor >= 0 else {
            fileWatcherLogger.warning("Could not open file for watching: \(sessionFile)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend],
            queue: .main
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
        fileWatchers[sessionId] = source
        fileWatcherLogger.debug("Started file watcher for session \(sessionId)")
    }

    func stopWatching(sessionId: String) {
        guard let watcher = fileWatchers.removeValue(forKey: sessionId) else {
            return
        }

        watcher.cancel()
        fileWatcherLogger.debug("Stopped file watcher for session \(sessionId)")
    }
}
