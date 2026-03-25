//
//  KeychainHelper.swift
//  constructionApp
//

import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.lyztw.constructionApp.auth"
    private static let accessAccount = "accessToken"
    private static let refreshAccount = "refreshToken"

    static func saveToken(_ token: String) {
        saveGeneric(account: accessAccount, value: token)
    }

    static func readToken() -> String? {
        readGeneric(account: accessAccount)
    }

    static func deleteToken() {
        deleteGeneric(account: accessAccount)
    }

    static func saveRefreshToken(_ token: String) {
        saveGeneric(account: refreshAccount, value: token)
    }

    static func readRefreshToken() -> String? {
        readGeneric(account: refreshAccount)
    }

    static func deleteRefreshToken() {
        deleteGeneric(account: refreshAccount)
    }

    static func deleteAllAuthSecrets() {
        deleteToken()
        deleteRefreshToken()
    }

    private static func saveGeneric(account: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func readGeneric(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteGeneric(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
