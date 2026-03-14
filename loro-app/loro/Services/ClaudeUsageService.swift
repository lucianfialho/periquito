import Foundation
import os.log

private let logger = Logger(subsystem: "com.ruban.loro", category: "ClaudeUsageService")

@MainActor @Observable
final class ClaudeUsageService {
    static let shared = ClaudeUsageService()

    var currentUsage: QuotaPeriod?
    var isLoading = false
    var error: String?
    var isConnected = false

    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let authFailureStatusCodes: Set<Int> = [401, 403]

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 60
    private var cachedToken: String?

    private init() {}

    func connectAndStartPolling() {
        AppSettings.isUsageEnabled = true
        error = nil
        stopPolling()

        Task {
            guard let accessToken = KeychainManager.getAccessToken() else {
                error = "Keychain access required"
                isConnected = false
                AppSettings.isUsageEnabled = false
                return
            }
            await fetchAndStartPolling(with: accessToken)
        }
    }

    func startPolling() {
        stopPolling()

        Task {
            guard let accessToken = KeychainManager.getCachedOAuthToken() else {
                logger.info("No cached token, user must connect manually")
                isConnected = false
                AppSettings.isUsageEnabled = false
                return
            }
            AppSettings.isUsageEnabled = true
            await fetchAndStartPolling(with: accessToken)
        }
    }

    func retryNow() {
        error = nil
        stopPolling()
        Task {
            guard let accessToken = cachedToken else {
                connectAndStartPolling()
                return
            }
            await performFetch(with: accessToken)
            schedulePollTimer()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func fetchAndStartPolling(with accessToken: String) async {
        cachedToken = accessToken
        await performFetch(with: accessToken)
        schedulePollTimer()
    }

    private func schedulePollTimer() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchUsage()
            }
        }
        logger.info("Started usage polling (every \(self.pollInterval)s)")
    }

    private func fetchUsage() async {
        guard let accessToken = cachedToken else {
            logger.warning("No cached token available, stopping polling")
            stopPolling()
            return
        }

        await performFetch(with: accessToken)
    }

    private func performFetch(with accessToken: String) async {
        isLoading = true

        defer { isLoading = false }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Loro", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                return
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    if currentUsage == nil {
                        error = "Rate limited, polling every \(Int(pollInterval))s"
                    } else {
                        error = nil
                    }
                    logger.debug("Rate limited (429), will retry next poll cycle")
                    return
                }

                if Self.authFailureStatusCodes.contains(httpResponse.statusCode) {
                    cachedToken = nil
                    KeychainManager.clearCachedOAuthToken()

                    if let freshToken = KeychainManager.refreshAccessTokenSilently(),
                       freshToken != accessToken {
                        logger.info("Token refreshed silently from Claude Code keychain")
                        await fetchAndStartPolling(with: freshToken)
                        return
                    }

                    error = "Token expired"
                    isConnected = false
                    stopPolling()
                } else {
                    error = "HTTP \(httpResponse.statusCode)"
                }
                logger.warning("API error: HTTP \(httpResponse.statusCode)")
                return
            }

            let usageResponse = try JSONDecoder().decode(UsageResponse.self, from: data)
            isConnected = true
            error = nil
            currentUsage = usageResponse.fiveHour
            logger.info("Usage fetched: \(self.currentUsage?.usagePercentage ?? 0)%")

        } catch {
            self.error = "Network error"
            logger.error("Fetch failed: \(error.localizedDescription)")
        }
    }
}
