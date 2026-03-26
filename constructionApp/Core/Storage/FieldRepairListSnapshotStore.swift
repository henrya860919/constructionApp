//
//  FieldRepairListSnapshotStore.swift
//  constructionApp
//
//  離線時還原上次成功載入的報修列表（依專案、狀態篩選、搜尋關鍵字分檔）。
//

import CryptoKit
import Foundation

enum FieldRepairListSnapshotStore {
    private static let subfolder = "RepairListSnapshots"
    private static let fileManager = FileManager.default

    private static var directoryURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FieldAppCache", isDirectory: true)
            .appendingPathComponent(subfolder, isDirectory: true)
    }

    private static func keyHex(projectId: String, statusFilterKey: String, searchQuery: String) -> String {
        let raw = "\(projectId)|\(statusFilterKey)|\(searchQuery)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func fileURL(projectId: String, statusFilterKey: String, searchQuery: String) -> URL {
        directoryURL.appendingPathComponent("\(keyHex(projectId: projectId, statusFilterKey: statusFilterKey, searchQuery: searchQuery)).json", isDirectory: false)
    }

    struct Payload: Codable, Sendable {
        var items: [RepairListItemDTO]
        var meta: PageMetaDTO?
    }

    static func save(
        projectId: String,
        statusFilterKey: String,
        searchQuery: String,
        items: [RepairListItemDTO],
        meta: PageMetaDTO?
    ) {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let payload = Payload(items: items, meta: meta)
            let data = try JSONEncoder().encode(payload)
            let url = fileURL(projectId: projectId, statusFilterKey: statusFilterKey, searchQuery: searchQuery)
            try data.write(to: url, options: .atomic)
        } catch {
            // 快取失敗不阻擋列表顯示
        }
    }

    static func load(projectId: String, statusFilterKey: String, searchQuery: String) -> Payload? {
        let url = fileURL(projectId: projectId, statusFilterKey: statusFilterKey, searchQuery: searchQuery)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// 與 `FieldCacheStorage.clearAllCaches` 一併清除。
    static func removeAllFiles() {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        guard let items = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }
}
