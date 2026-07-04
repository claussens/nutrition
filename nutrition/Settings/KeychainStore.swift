import Foundation
import Security

// Keychain wrapper holding the app's credentials: the user's Anthropic API
// key and the GitHub PAT used by ConfigSync.
//
// Why Keychain (not UserDefaults): the rest of the app stores ingredient
// data in UserDefaults, but a third-party API key is a credential — it
// belongs in the Keychain so it's encrypted at rest, survives reinstall,
// and never lands in iCloud Backup as plain text.
//
// We use one account string per credential (`anthropic-api-key`,
// `github-pat`) under one service (`com.sclaussen.nutrition`). If we ever
// add another key (OpenAI, etc.) we just add another `account` string.
enum KeychainStore {

    private static let service = "com.sclaussen.nutrition"
    private static let anthropicAccount = "anthropic-api-key"
    private static let githubAccount = "github-pat"


    static func anthropicKey() -> String? {
        return read(account: anthropicAccount)
    }


    @discardableResult
    static func setAnthropicKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return delete(account: anthropicAccount)
        } else {
            return write(account: anthropicAccount, value: trimmed)
        }
    }


    /// The stored GitHub personal access token, or nil if none is set.
    static func githubToken() -> String? {
        #if DEBUG
        // Test override: a token supplied via the launch environment
        // (SIMCTL_CHILD_GITHUB_API_KEY in the Simulator) takes precedence so we
        // can exercise refresh without pasting into a SecureField — and without
        // a stale Keychain entry shadowing it. Never compiled into release.
        if let env = ProcessInfo.processInfo.environment["GITHUB_API_KEY"],
           !env.isEmpty {
            return env
        }
        #endif
        if let stored = read(account: githubAccount), !stored.isEmpty {
            return stored
        }
        return nil
    }


    /// Store (or clear, when empty) the GitHub personal access token.
    @discardableResult
    static func setGitHubToken(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return delete(account: githubAccount)
        } else {
            return write(account: githubAccount, value: trimmed)
        }
    }


    // ============================================================
    // Internals
    // ============================================================

    private static func baseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }


    private static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }


    // Write-or-update: SecItemAdd fails with errSecDuplicateItem if the
    // key already exists, in which case we fall through to SecItemUpdate.
    // Returns false (and logs the OSStatus) if either call fails.
    private static func write(account: String, value: String) -> Bool {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        // Stay on-device: don't sync to iCloud Keychain.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        if addStatus == errSecDuplicateItem {
            let update: [String: Any] = [
                kSecValueData as String: data,
                // Re-assert accessibility so an existing item written under the
                // old (syncable) class gets upgraded the next time it's saved.
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary,
                                             update as CFDictionary)
            if updateStatus != errSecSuccess {
                print("KeychainStore: SecItemUpdate failed for \(account) (OSStatus \(updateStatus))")
                return false
            }
            return true
        }
        print("KeychainStore: SecItemAdd failed for \(account) (OSStatus \(addStatus))")
        return false
    }


    // Treats errSecItemNotFound as success — clearing an absent item is fine.
    @discardableResult
    private static func delete(account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("KeychainStore: SecItemDelete failed for \(account) (OSStatus \(status))")
            return false
        }
        return true
    }
}
