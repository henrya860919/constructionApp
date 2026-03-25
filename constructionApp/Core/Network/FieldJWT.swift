//
//  FieldJWT.swift
//  constructionApp
//
//  僅解出 JWT payload 的 exp（不驗簽），供客戶端決定是否先 refresh。
//

import Foundation

enum FieldJWT {
    /// 若無法解析或無 exp，視為應盡快向伺服器確認（傳回過去時間）。
    static func expirationDate(jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - base64.count % 4
        if pad < 4 {
            base64 += String(repeating: "=", count: pad)
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    /// 在過期前 `leewaySeconds` 秒即視為需要換發。
    static func shouldProactivelyRefresh(jwt: String, leewaySeconds: TimeInterval = 120) -> Bool {
        guard let exp = expirationDate(jwt: jwt) else { return true }
        return Date().addingTimeInterval(leewaySeconds) >= exp
    }

    static func isLikelyExpired(jwt: String) -> Bool {
        guard let exp = expirationDate(jwt: jwt) else { return true }
        return Date() >= exp
    }
}
