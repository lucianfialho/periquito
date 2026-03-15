import Foundation
import Security

enum KeychainManager {
    private static let claudeCodeService = "Claude Code-credentials"
    private static let periquitoService = "com.lucianfialho.periquito"
    private static let anthropicApiKeyAccount = "anthropicApiKey"
    private static let cachedOAuthTokenAccount = "cachedOAuthToken"

    static func getAccessToken() -> String? {
        readAndCacheAccessToken(allowInteraction: true)
    }

    static func refreshAccessTokenSilently() -> String? {
        readAndCacheAccessToken(allowInteraction: false)
    }

    // MARK: - Anthropic API Key

    static func getAnthropicApiKey() -> String? {
        readString(service: periquitoService, account: anthropicApiKeyAccount)
    }

    static func setAnthropicApiKey(_ key: String?) {
        if let key, !key.isEmpty {
            saveString(key, service: periquitoService, account: anthropicApiKeyAccount)
        } else {
            deleteItem(service: periquitoService, account: anthropicApiKeyAccount)
        }
    }

    // MARK: - Cached OAuth Token

    static func getCachedOAuthToken() -> String? {
        readString(service: periquitoService, account: cachedOAuthTokenAccount)
    }

    static func cacheOAuthToken(_ token: String) {
        saveString(token, service: periquitoService, account: cachedOAuthTokenAccount)
    }

    static func clearCachedOAuthToken() {
        deleteItem(service: periquitoService, account: cachedOAuthTokenAccount)
    }

    // MARK: - Claude Code Credentials

    private static func readAndCacheAccessToken(allowInteraction: Bool) -> String? {
        guard let json = readClaudeCodeKeychain(allowInteraction: allowInteraction),
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        cacheOAuthToken(token)
        return token
    }

    private static func readClaudeCodeKeychain(allowInteraction: Bool) -> [String: Any]? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: claudeCodeService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if !allowInteraction {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    // MARK: - Generic Keychain Helpers

    private static func readString(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private static func saveString(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)

        // Try to update existing item first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func deleteItem(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
