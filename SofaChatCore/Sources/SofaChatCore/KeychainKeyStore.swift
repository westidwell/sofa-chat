#if canImport(Security)
import Foundation
import Security

/// Stores the key in the device Keychain. "ThisDeviceOnly" keeps it out of
/// backups and iCloud Keychain, so it stays on this Apple TV.
public final class KeychainKeyStore: APIKeyStore {
    private let service: String
    private let account: String

    public init(service: String = "sofa-chat", account: String = "api-key") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func loadKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeyStoreError.storageFailed(status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func saveKey(_ key: String) throws {
        let data = Data(key.utf8)
        let changes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeyStoreError.storageFailed(status)
        }
    }

    public func deleteKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.storageFailed(status)
        }
    }
}
#endif
