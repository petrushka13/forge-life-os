import Foundation
import Security

struct KeychainFailure: Error, LocalizedError {
    let operation: String
    let status: OSStatus
    var errorDescription: String? {
        let state: String
        switch status {
        case errSecInteractionNotAllowed: state = "locked or interaction unavailable"
        case errSecAuthFailed, errSecUserCanceled: state = "authorization denied"
        case errSecDuplicateItem: state = "duplicate item"
        case errSecItemNotFound: state = "missing item"
        case errSecNotAvailable: state = "unavailable"
        default: state = "system failure"
        }
        return "Keychain \(operation): \(state) (OSStatus \(status)). No credential was logged."
    }
}
enum Keychain {
    static let service = "com.personal.FORGE"
    static func query(_ key: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key] }
    static func readValue(_ key: String) throws -> String? {
        var query = query(key); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainFailure(operation: "read", status: status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw KeychainFailure(operation: "decode", status: errSecDecode) }
        return value
    }
    static func delete(_ key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainFailure(operation: "delete", status: status) }
    }
    static func save(_ value: String, key: String) throws {
        if value.isEmpty { try delete(key); return }
        let query = query(key), attributes = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var entry = query; entry.merge(attributes) { _, new in new }; entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(entry as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainFailure(operation: "add", status: added) }
        } else if status != errSecSuccess { throw KeychainFailure(operation: "update", status: status) }
    }
    /// Roll back credentials if either Keychain or local persistence fails. There is
    /// no cross-store OS transaction; rollback failure is explicit and blocks imports.
    static func transaction(_ values: [String: String], commit: () throws -> Void) throws {
        var previous: [String: String] = [:]
        for key in values.keys { previous[key] = try readValue(key) ?? "" }
        do { for (key, value) in values { try save(value, key: key) }; try commit() }
        catch {
            let original = error
            do { for (key, value) in previous { try save(value, key: key) } }
            catch { throw NSError(domain: "FORGE", code: 1, userInfo: [NSLocalizedDescriptionKey: "Settings were not saved. Credential rollback also failed; unlock Keychain and save both credentials again before importing."]) }
            throw original
        }
    }
}
