//
//  FieldAppVersionChecker.swift
//  constructionApp
//

import Foundation
import Observation

/// 啟動時呼叫 `GET /app/version`，若本機版號低於伺服器 `minimumVersion` 則阻擋使用。
@MainActor
@Observable
final class FieldAppVersionChecker {
    static let shared = FieldAppVersionChecker()

    private(set) var requiresForceUpdate = false
    private(set) var appStoreURL: URL?
    private(set) var lastCheckFailedMessage: String?
    /// 完成一次啟動版號檢查後為 true（失敗也會設為 true，以免卡住啟動）。
    private(set) var didFinishLaunchCheck = false

    func evaluateAtLaunch() async {
        lastCheckFailedMessage = nil
        defer { didFinishLaunchCheck = true }
        do {
            try AppConfiguration.validateAPIBaseIsSecureForRequests()
            let dto = try await APIService.fetchAppVersion(baseURL: AppConfiguration.apiRootURL)
            let local = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            if FieldSemanticVersion.compare(local, isLessThan: dto.minimumVersion) {
                requiresForceUpdate = true
                appStoreURL = URL(string: dto.appStoreURL)
            }
        } catch {
            lastCheckFailedMessage = (error as? APIRequestError)?.localizedDescription ?? error.localizedDescription
        }
    }
}

enum FieldSemanticVersion {
    /// `a < b` 語意化比較（僅數字段，不足補 0）。
    static func compare(_ a: String, isLessThan b: String) -> Bool {
        let pa = parse(a)
        let pb = parse(b)
        let n = max(pa.count, pb.count)
        for i in 0 ..< n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x < y { return true }
            if x > y { return false }
        }
        return false
    }

    private static func parse(_ s: String) -> [Int] {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        return parts.map { sub in
            let digits = sub.filter(\.isNumber)
            return Int(String(digits)) ?? 0
        }
    }
}
