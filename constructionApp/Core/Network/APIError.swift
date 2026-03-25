//
//  APIError.swift
//  constructionApp
//

import Foundation

struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
    }

    let error: Detail
}

enum APIRequestError: Error, LocalizedError, Equatable {
    case invalidURL
    /// Release／非本機 API 必須為 https。
    case apiMustUseHTTPS
    case httpStatus(Int, String?)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "網址無效"
        case .apiMustUseHTTPS:
            return "API 必須使用 HTTPS"
        case let .httpStatus(code, message):
            if let message, !message.isEmpty { return message }
            return "伺服器錯誤（\(code)）"
        case .decodingFailed:
            return "資料解析失敗"
        case .transport:
            return "無法連線，請檢查網路或 API 位址"
        }
    }

    static func == (lhs: APIRequestError, rhs: APIRequestError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): true
        case (.apiMustUseHTTPS, .apiMustUseHTTPS): true
        case let (.httpStatus(a, am), .httpStatus(b, bm)): a == b && am == bm
        case (.decodingFailed, .decodingFailed): true
        case (.transport, .transport): true
        default: false
        }
    }
}

extension Error {
    /// 無網路／連線中斷等，可改為寫入離線佇列。
    var isLikelyConnectivityFailure: Bool {
        if let api = self as? APIRequestError, case .transport = api { return true }
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorTimedOut,
                 NSURLErrorDataNotAllowed:
                return true
            default:
                break
            }
        }
        if let url = self as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut, .dataNotAllowed:
                return true
            default:
                break
            }
        }
        return false
    }

    /// 下拉重整、搜尋 debounce、`.task` 重跑時會取消尚未完成的網路請求；不應顯示成錯誤（畫面上常變成英文 "cancelled"）。
    var isIgnorableTaskCancellation: Bool {
        if self is CancellationError { return true }
        if let url = self as? URLError, url.code == .cancelled { return true }
        if let api = self as? APIRequestError, case let .transport(inner) = api {
            return inner.isIgnorableTaskCancellation
        }
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return true }
        return false
    }
}
