import Foundation
import Security

// MARK: - SecretStore

protocol SecretStore {
    func save(_ data: Data, for key: String) throws
    func load(_ key: String) -> Data?
    func delete(_ key: String)
}

// MARK: - KeychainService

struct KeychainService: SecretStore {
    enum KeychainError: Error { case unexpectedStatus(OSStatus) }
    let service: String

    init(service: String = "com.einfochips.PatientHealth") { self.service = service }

    private func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    /// Saves or replaces a secret in the Keychain.
    /// Uses WhenUnlockedThisDeviceOnly so it never syncs or migrates.
    /// Throws KeychainError on failure.
    func save(_ data: Data, for key: String) throws {
        SecItemDelete(baseQuery(key) as CFDictionary)
        var q = baseQuery(key)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    /// Loads a secret from the Keychain.
    /// Returns nil when absent or unreadable.
    /// Returns the stored data.
    func load(_ key: String) -> Data? {
        var q = baseQuery(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    /// Deletes a secret from the Keychain.
    /// Safe to call when the item does not exist.
    /// Returns nothing.
    func delete(_ key: String) { SecItemDelete(baseQuery(key) as CFDictionary) }
}
