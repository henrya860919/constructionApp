//
//  FieldCacheStorage.swift
//  constructionApp
//

import CryptoKit
import Foundation

extension Notification.Name {
    /// 暫存用量變更（清除或修剪後），供設定列表列更新摘要。
    static let fieldCacheStorageDidChange = Notification.Name("FieldCacheStorage.didChange")
}

/// 設定頁「暫存空間」：可清除的網路與圖片快取，不含未上傳草稿／Outbox。
enum FieldCacheStorage {
    /// UI 顯示的上限（與產品規格一致）。
    static let displayBudgetBytes: Int64 = 120 * 1024 * 1024

    /// 超過上限時修剪到此比例以下（僅針對自管圖片目錄與必要時清空 URLCache）。
    private static let trimTargetFraction = 0.8

    private static var trimTargetBytes: Int64 {
        Int64(Double(displayBudgetBytes) * trimTargetFraction)
    }

    private static let urlCacheMemoryBytes = 20 * 1024 * 1024
    /// 與顯示上限留白給圖片磁碟快取。
    private static let urlCacheDiskBytes = 80 * 1024 * 1024

    private static let cacheFolderName = "FieldAppCache"
    private static let imageSubfolder = "AuthenticatedImages"

    private static let fileManager = FileManager.default

    // MARK: - Paths

    static var imageCacheDirectoryURL: URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(cacheFolderName, isDirectory: true)
            .appendingPathComponent(imageSubfolder, isDirectory: true)
        return base
    }

    // MARK: - Launch

    static func configureAtLaunch() {
        let diskURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(cacheFolderName, isDirectory: true)
            .appendingPathComponent("URLCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskURL, withIntermediateDirectories: true)

        let cache = URLCache(
            memoryCapacity: urlCacheMemoryBytes,
            diskCapacity: urlCacheDiskBytes,
            diskPath: diskURL.path
        )
        URLCache.shared = cache
    }

    // MARK: - Usage

    struct UsageBreakdown: Sendable {
        var networkBytes: Int64
        var imageBytes: Int64
        /// 離線圖說預載（獨立 40MB 槽，見 `FieldOfflineDrawingQuota`）。
        var offlineDrawingBytes: Int64

        /// 納入本頁「一般暫存」120MB 配額的用量（網路＋圖片快取）。
        var managedCacheBytes: Int64 { networkBytes + imageBytes }

        /// 全部可從設定頁看到的磁碟暫存加總（含離線圖說）。
        var totalBytes: Int64 { managedCacheBytes + offlineDrawingBytes }
    }

    static func usageBreakdown() -> UsageBreakdown {
        let network = Int64(URLCache.shared.currentDiskUsage)
        let image = directoryByteCount(at: imageCacheDirectoryURL)
        let offline = FieldOfflineDrawingStore.totalBytes()
        return UsageBreakdown(networkBytes: network, imageBytes: image, offlineDrawingBytes: offline)
    }

    /// App 回到前景等時機呼叫；超過預算則修剪（**不**修剪離線圖說預載）。
    static func trimIfNeeded() {
        let b = usageBreakdown()
        let managed = b.managedCacheBytes
        guard managed > displayBudgetBytes else { return }

        URLCache.shared.removeAllCachedResponses()

        let imageTotal = directoryByteCount(at: imageCacheDirectoryURL)
        let net = Int64(URLCache.shared.currentDiskUsage)
        if imageTotal + net > trimTargetBytes {
            trimImageCacheLRUUntilUnderBudget()
        }
        NotificationCenter.default.post(name: .fieldCacheStorageDidChange, object: nil)
    }

    /// 在已清空或縮小 URLCache 後，依檔案修改時間由舊到新刪除，直到總用量低於目標。
    private static func trimImageCacheLRUUntilUnderBudget() {
        while usageBreakdown().managedCacheBytes > trimTargetBytes {
            guard let oldest = oldestImageFileURL() else { break }
            try? fileManager.removeItem(at: oldest)
        }
    }

    private static func oldestImageFileURL() -> URL? {
        guard fileManager.fileExists(atPath: imageCacheDirectoryURL.path) else { return nil }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: imageCacheDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var best: (url: URL, date: Date)?
        for url in urls {
            guard let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mod = vals.contentModificationDate
            else { continue }
            if best == nil || mod < best!.date {
                best = (url, mod)
            }
        }
        return best?.url
    }

    // MARK: - Clear

    /// 清除網路快取與授權圖片磁碟快取。
    static func clearAllCaches() {
        URLCache.shared.removeAllCachedResponses()
        removeContentsOfDirectory(at: imageCacheDirectoryURL)
        FieldRepairListSnapshotStore.removeAllFiles()
        FieldDefectListSnapshotStore.removeAllFiles()
        FieldSelfInspectionTemplatesSnapshotStore.removeAllFiles()
        FieldSelfInspectionTemplateRecordsSnapshotStore.removeAllFiles()
        NotificationCenter.default.post(name: .fieldCacheStorageDidChange, object: nil)
    }

    // MARK: - Image disk I/O（供 AuthenticatedRemoteImage）

    static func imageFileURL(forApiPath apiPath: String) -> URL {
        let name = Self.sha256Hex(apiPath) + ".img"
        return imageCacheDirectoryURL.appendingPathComponent(name, isDirectory: false)
    }

    static func readCachedImageData(forApiPath apiPath: String) -> Data? {
        let url = imageFileURL(forApiPath: apiPath)
        return try? Data(contentsOf: url)
    }

    static func writeCachedImageData(_ data: Data, forApiPath apiPath: String) {
        let dir = imageCacheDirectoryURL
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = imageFileURL(forApiPath: apiPath)
            try data.write(to: url, options: .atomic)
        } catch {
            // 快取寫入失敗不阻擋顯示
        }
    }

    // MARK: - Private

    private static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func directoryByteCount(at url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                vals.isRegularFile == true,
                let size = vals.fileSize
            else { continue }
            total += Int64(size)
        }
        return total
    }

    private static func removeContentsOfDirectory(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        guard let items = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }
}

// MARK: - Formatting（設定畫面共用）

enum FieldByteCountFormatter {
    static func megabytesString(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb < 0.1, bytes > 0 {
            return String(format: "%.2f MB", max(mb, 0.01))
        }
        if mb < 10 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.0f MB", mb)
    }
}
