//
//  AppConfiguration.swift
//  constructionApp
//

import Foundation

/// API root including `/api/v1`, aligned with dashboard `VITE_API_URL`.
enum AppConfiguration {
    /// Override with Xcode Scheme → Run → Environment: `API_BASE_URL` = `http://127.0.0.1:3003/api/v1`
    static var apiRootURL: URL {
        if let raw = ProcessInfo.processInfo.environment["API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        #if DEBUG
        return URL(string: "http://127.0.0.1:3003/api/v1")!
        #else
        // Release／TestFlight／App Store：預設正式後端（與 Railway Public URL 一致；若改網域請一併更新）
        return URL(string: "https://construction-dashboard-backend-production.up.railway.app/api/v1")!
        #endif
    }

    /// Host root without path (e.g. `http://127.0.0.1:3003`) — 用於組 `/api/v1/files/...` 完整 URL。
    static var serverOriginURL: URL {
        apiRootURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// 將後端回傳的相對路徑（如 `/api/v1/files/{id}`）轉成絕對 URL。
    static func absoluteURL(apiPath: String) -> URL? {
        let path = apiPath.hasPrefix("/") ? apiPath : "/" + apiPath
        return URL(string: path, relativeTo: serverOriginURL)?.absoluteURL
    }
}
