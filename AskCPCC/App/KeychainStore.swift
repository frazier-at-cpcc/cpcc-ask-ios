import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case dataMalformed
}

enum KeychainStore {

    static let openRouterService = "edu.cpcc.AskCPCC.openrouter"
    static let openRouterAccount = "key"

    static func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataMalformed
        }
        return s
    }

    static func write(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        try delete(service: service, account: account)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func readOpenRouterKey() throws -> String? {
        try read(service: openRouterService, account: openRouterAccount)
    }

    static func writeOpenRouterKey(_ key: String) throws {
        try write(key, service: openRouterService, account: openRouterAccount)
    }

    static func deleteOpenRouterKey() throws {
        try delete(service: openRouterService, account: openRouterAccount)
    }
}
