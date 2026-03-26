//
//  FieldOfflineDrawingStore.swift
//  constructionApp
//
//  使用者明確「預先下載」的圖說檔案，供離線 Quick Look；與 URLCache／授權圖片快取分開計量。
//  配額獨立於 FieldCacheStorage.displayBudgetBytes，避免自動修剪誤刪意圖性離線資料。
//

import CryptoKit
import Foundation

extension Notification.Name {
    /// 離線圖說預載寫入／刪除後，與暫存用量一併刷新 UI。
    static let fieldOfflineDrawingStoreDidChange = Notification.Name("FieldOfflineDrawingStore.didChange")
}

// MARK: - 配額策略（與一般快取分離）

/// 離線圖說預載專用上限（不依賴系統 URLCache 自動修剪）。
enum FieldOfflineDrawingQuota {
    /// 預留給「使用者主動預載」的圖說檔案；與 `FieldCacheStorage` 的 120MB（網路＋列表圖片快取）分開。
    static let vaultBudgetBytes: Int64 = 40 * 1024 * 1024
}

// MARK: - Index

private struct OfflineDrawingIndexFile: Codable, Sendable {
    var items: [OfflineDrawingIndexEntry]
}

struct OfflineDrawingIndexEntry: Codable, Sendable, Identifiable {
    /// 與 `attachmentId` 相同，方便 SwiftUI。
    var id: String { attachmentId }
    var projectId: String
    var nodeId: String
    var attachmentId: String
    var fileName: String
    var byteCount: Int64
    var savedAt: Date
}

enum FieldOfflineDrawingStoreError: Error, LocalizedError {
    case overQuota(needed: Int64, available: Int64)

    var errorDescription: String? {
        switch self {
        case let .overQuota(needed, available):
            let n = FieldByteCountFormatter.megabytesString(needed)
            let a = FieldByteCountFormatter.megabytesString(available)
            return "離線圖說空間不足：需要約 \(n)，目前約可再使用 \(a)。請先釋出空間後再繼續下載。"
        }
    }
}

enum FieldOfflineDrawingStore {
    private static let cacheFolderName = "FieldAppCache"
    private static let subfolder = "OfflineDrawings"
    private static let indexFileName = "index.json"

    private static let fileManager = FileManager.default

    private static var rootURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(cacheFolderName, isDirectory: true)
            .appendingPathComponent(subfolder, isDirectory: true)
    }

    private static var indexURL: URL {
        rootURL.appendingPathComponent(indexFileName, isDirectory: false)
    }

    private static func blobURL(attachmentId: String) -> URL {
        rootURL.appendingPathComponent("files", isDirectory: true)
            .appendingPathComponent(safeFileName(attachmentId), isDirectory: false)
    }

    private static func safeFileName(_ attachmentId: String) -> String {
        let h = sha256Hex(attachmentId)
        return "\(h).blob"
    }

    private static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func loadIndex() -> OfflineDrawingIndexFile {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode(OfflineDrawingIndexFile.self, from: data) else {
            return OfflineDrawingIndexFile(items: [])
        }
        return decoded
    }

    private static func saveIndex(_ file: OfflineDrawingIndexFile) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let filesDir = rootURL.appendingPathComponent("files", isDirectory: true)
        try fileManager.createDirectory(at: filesDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(file)
        try data.write(to: indexURL, options: .atomic)
    }

    private static func notifyChanged() {
        NotificationCenter.default.post(name: .fieldOfflineDrawingStoreDidChange, object: nil)
        NotificationCenter.default.post(name: .fieldCacheStorageDidChange, object: nil)
    }

    // MARK: - Public read

    static func totalBytes() -> Int64 {
        loadIndex().items.reduce(0) { $0 + $1.byteCount }
    }

    static func vaultBudgetBytes() -> Int64 {
        FieldOfflineDrawingQuota.vaultBudgetBytes
    }

    static func availableBytes() -> Int64 {
        max(0, FieldOfflineDrawingQuota.vaultBudgetBytes - totalBytes())
    }

    static func entries(forProjectId projectId: String) -> [OfflineDrawingIndexEntry] {
        loadIndex().items.filter { $0.projectId == projectId }
    }

    static func allEntries() -> [OfflineDrawingIndexEntry] {
        loadIndex().items
    }

    /// 若已預載則回傳本機檔案 URL（供 Quick Look）。
    static func localFileURLIfExists(projectId: String, attachmentId: String) -> URL? {
        let items = loadIndex().items
        guard let entry = items.first(where: { $0.projectId == projectId && $0.attachmentId == attachmentId }) else {
            return nil
        }
        let url = blobURL(attachmentId: entry.attachmentId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// 預載檔以雜湊檔名儲存（無副檔名），Quick Look 需依副檔名辨識 PDF／圖檔等；複製到暫存並保留檔名。
    /// `displayFileName` 優先（與畫面上修訂名一致），否則用索引內預載時的檔名。
    static func temporaryURLForQuickLook(
        projectId: String,
        attachmentId: String,
        displayFileName: String?
    ) -> URL? {
        let items = loadIndex().items
        guard let entry = items.first(where: { $0.projectId == projectId && $0.attachmentId == attachmentId }) else {
            return nil
        }
        let src = blobURL(attachmentId: attachmentId)
        guard fileManager.fileExists(atPath: src.path) else { return nil }

        let fromDisplay = displayFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName: String
        if let fromDisplay, !fromDisplay.isEmpty {
            rawName = fromDisplay
        } else {
            rawName = entry.fileName
        }
        let baseName = rawName.replacingOccurrences(of: "/", with: "_")

        let dest = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + baseName, isDirectory: false)
        if fileManager.fileExists(atPath: dest.path) {
            try? fileManager.removeItem(at: dest)
        }
        do {
            try fileManager.copyItem(at: src, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    static func hasFile(projectId: String, attachmentId: String) -> Bool {
        localFileURLIfExists(projectId: projectId, attachmentId: attachmentId) != nil
    }

    // MARK: - Write / delete

    /// 寫入或覆寫同一 `attachmentId`（同一檔新版本替換舊檔）。
    static func save(
        projectId: String,
        nodeId: String,
        attachmentId: String,
        fileName: String,
        data: Data
    ) throws {
        let newSize = Int64(data.count)
        var idx = loadIndex()
        let oldSize = idx.items.first(where: { $0.attachmentId == attachmentId })?.byteCount ?? 0
        let projected = totalBytes() - oldSize + newSize
        guard projected <= FieldOfflineDrawingQuota.vaultBudgetBytes else {
            let avail = max(0, FieldOfflineDrawingQuota.vaultBudgetBytes - (totalBytes() - oldSize))
            throw FieldOfflineDrawingStoreError.overQuota(needed: newSize, available: avail)
        }

        let blob = blobURL(attachmentId: attachmentId)
        try fileManager.createDirectory(at: blob.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: blob, options: .atomic)

        idx.items.removeAll { $0.attachmentId == attachmentId }
        idx.items.append(
            OfflineDrawingIndexEntry(
                projectId: projectId,
                nodeId: nodeId,
                attachmentId: attachmentId,
                fileName: fileName,
                byteCount: newSize,
                savedAt: Date()
            )
        )
        try saveIndex(idx)
        notifyChanged()
    }

    /// 依最舊的預載逐一刪除，直到釋出至少 `byteGoal`（或已空）；回傳實際釋出量。
    @discardableResult
    static func freeSpaceByTrimmingLRU(byteGoal: Int64) -> Int64 {
        guard byteGoal > 0 else { return 0 }
        var idx = loadIndex()
        var freed: Int64 = 0
        let sorted = idx.items.sorted { $0.savedAt < $1.savedAt }
        for entry in sorted {
            guard freed < byteGoal else { break }
            let url = blobURL(attachmentId: entry.attachmentId)
            try? fileManager.removeItem(at: url)
            idx.items.removeAll { $0.attachmentId == entry.attachmentId }
            freed += entry.byteCount
        }
        try? saveIndex(idx)
        notifyChanged()
        return freed
    }

    static func remove(attachmentId: String) {
        var idx = loadIndex()
        guard idx.items.contains(where: { $0.attachmentId == attachmentId }) else { return }
        let url = blobURL(attachmentId: attachmentId)
        try? fileManager.removeItem(at: url)
        idx.items.removeAll { $0.attachmentId == attachmentId }
        try? saveIndex(idx)
        notifyChanged()
    }

    static func removeAll(forProjectId projectId: String) {
        var idx = loadIndex()
        let toRemove = idx.items.filter { $0.projectId == projectId }
        for e in toRemove {
            try? fileManager.removeItem(at: blobURL(attachmentId: e.attachmentId))
        }
        idx.items.removeAll { $0.projectId == projectId }
        try? saveIndex(idx)
        notifyChanged()
    }

    /// 清除全部離線圖說預載（設定頁）。
    static func removeAll() {
        let idx = loadIndex()
        for e in idx.items {
            try? fileManager.removeItem(at: blobURL(attachmentId: e.attachmentId))
        }
        try? saveIndex(OfflineDrawingIndexFile(items: []))
        notifyChanged()
    }
}
