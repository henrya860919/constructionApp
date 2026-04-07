//
//  AppConfiguration.swift
//  constructionApp
//

import Foundation

/// API root including `/api/v1`, aligned with dashboard `VITE_API_URL`.
enum AppConfiguration: Sendable {
    /// 正式環境後端（Release／TestFlight／App Store 預設）：
    /// https://construction-dashboard-backend-production.up.railway.app/api/v1
    private static let productionAPIRootURLString =
        "https://construction-dashboard-backend-production.up.railway.app/api/v1"

    /// DEBUG 預設：家裡區網後端（本機請改此常數或設環境變數 `API_BASE_URL`）。
    private static let debugDefaultAPIRootURLString = "http://192.168.0.33:3003/api/v1"

    /// Override with Xcode Scheme → Run → Environment: `API_BASE_URL`（例 `http://127.0.0.1:3003/api/v1`）
    nonisolated static var apiRootURL: URL {
        if let raw = ProcessInfo.processInfo.environment["API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        #if DEBUG
        return URL(string: debugDefaultAPIRootURLString)!
        #else
        return URL(string: productionAPIRootURLString)!
        #endif
    }

    /// Host root without path (e.g. `http://127.0.0.1:3003`) — 用於組 `/api/v1/files/...` 完整 URL。
    nonisolated static var serverOriginURL: URL {
        apiRootURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// 將後端回傳的相對路徑（如 `/api/v1/files/{id}`）轉成絕對 URL。
    nonisolated static func absoluteURL(apiPath: String) -> URL? {
        let path = apiPath.hasPrefix("/") ? apiPath : "/" + apiPath
        return URL(string: path, relativeTo: serverOriginURL)?.absoluteURL
    }

    private nonisolated static func isLocalhostAPIHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    /// DEBUG 專用：允許區網 IPv4（RFC 1918）走 http，方便家裡／內網後端。
    private nonisolated static func isPrivateIPv4LANHost(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let octets = host.split(separator: ".")
        guard octets.count == 4,
              let a = Int(octets[0]), let b = Int(octets[1]),
              let c = Int(octets[2]), let d = Int(octets[3]),
              (0 ... 255).contains(a), (0 ... 255).contains(b),
              (0 ... 255).contains(c), (0 ... 255).contains(d) else {
            return false
        }
        if a == 10 { return true }
        if a == 172, (16 ... 31).contains(b) { return true }
        if a == 192, b == 168 { return true }
        return false
    }

    /// 發出 API 請求前呼叫：Release 僅允許 https；DEBUG 允許本機或區網 http。
    nonisolated static func validateAPIBaseIsSecureForRequests() throws {
        let url = apiRootURL
        if url.scheme?.lowercased() == "https" { return }
        #if DEBUG
        if isLocalhostAPIHost(url) || isPrivateIPv4LANHost(url) { return }
        #endif
        throw APIRequestError.apiMustUseHTTPS
    }
}
