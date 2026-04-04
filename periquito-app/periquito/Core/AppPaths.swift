import Foundation

nonisolated enum AppPaths {
    static let learningDirectory: URL = {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".english-learning")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    static let historyFile = learningDirectory.appending(path: "history.jsonl")
    static let reviewsFile = learningDirectory.appending(path: "reviews.json")
    static let levelFile = learningDirectory.appending(path: "level.json")
}
