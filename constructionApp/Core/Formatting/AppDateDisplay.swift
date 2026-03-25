//
//  AppDateDisplay.swift
//  constructionApp
//
//  全 app 使用者可見時間：日期 + 24 小時制，本地時區。
//

import Foundation

enum AppDateDisplay {
    /// `yyyy-MM-dd HH:mm:ss`，西元年、24 小時制、裝置目前時區。
    static func string(from date: Date) -> String {
        displayFormatter.string(from: date)
    }

    /// 將後端 ISO8601（可含小數秒）轉成 `string(from:)`；無法解析則原樣回傳（例如純 `YYYY-MM-DD` 欄位）。
    static func string(fromAPISurface string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        guard let date = parseISO8601(trimmed) else { return trimmed }
        return displayFormatter.string(from: date)
    }

    private static func parseISO8601(_ string: String) -> Date? {
        if let d = isoFractional.date(from: string) { return d }
        if let d = isoPlain.date(from: string) { return d }
        return nil
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.timeZone = .current
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

extension String {
    /// API 回傳的 ISO8601 時間字串 → 畫面用日期時間；非 ISO 則不變。
    var formattedAsAppDateTime: String {
        AppDateDisplay.string(fromAPISurface: self)
    }
}
