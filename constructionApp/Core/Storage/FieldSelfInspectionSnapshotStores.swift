//
//  FieldSelfInspectionSnapshotStores.swift
//  constructionApp
//
//  離線時還原自主查驗：樣板列表、各樣板之 hub + 紀錄列表（第二層）。
//

import CryptoKit
import Foundation

enum FieldSelfInspectionTemplatesSnapshotStore {
    private static let subfolder = "SelfInspectionTemplatesSnapshots"
    private static let fileManager = FileManager.default

    private static var directoryURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FieldAppCache", isDirectory: true)
            .appendingPathComponent(subfolder, isDirectory: true)
    }

    private static func keyHex(projectId: String) -> String {
        let digest = SHA256.hash(data: Data(projectId.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func fileURL(projectId: String) -> URL {
        directoryURL.appendingPathComponent("\(keyHex(projectId: projectId)).json", isDirectory: false)
    }

    struct Payload: Codable, Sendable {
        var templates: [SelfInspectionProjectTemplateDTO]
    }

    static func save(projectId: String, templates: [SelfInspectionProjectTemplateDTO]) {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Payload(templates: templates))
            try data.write(to: fileURL(projectId: projectId), options: .atomic)
        } catch {
            // 快取失敗不阻擋列表顯示
        }
    }

    static func load(projectId: String) -> [SelfInspectionProjectTemplateDTO]? {
        let url = fileURL(projectId: projectId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data).templates
    }

    static func removeAllFiles() {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        guard let items = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }
}

enum FieldSelfInspectionTemplateRecordsSnapshotStore {
    private static let subfolder = "SelfInspectionTemplateRecordsSnapshots"
    private static let fileManager = FileManager.default

    private static var directoryURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FieldAppCache", isDirectory: true)
            .appendingPathComponent(subfolder, isDirectory: true)
    }

    private static func keyHex(projectId: String, templateId: String) -> String {
        let raw = "\(projectId)|\(templateId)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func fileURL(projectId: String, templateId: String) -> URL {
        directoryURL.appendingPathComponent("\(keyHex(projectId: projectId, templateId: templateId)).json", isDirectory: false)
    }

    struct Payload: Codable, Sendable {
        var hub: SelfInspectionTemplateHubDTO
        var records: [SelfInspectionRecordListDTO]
        var meta: PageMetaDTO?
    }

    static func save(
        projectId: String,
        templateId: String,
        hub: SelfInspectionTemplateHubDTO,
        records: [SelfInspectionRecordListDTO],
        meta: PageMetaDTO?
    ) {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let payload = Payload(hub: hub, records: records, meta: meta)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL(projectId: projectId, templateId: templateId), options: .atomic)
        } catch {
            // 快取失敗不阻擋列表顯示
        }
    }

    static func load(projectId: String, templateId: String) -> Payload? {
        let url = fileURL(projectId: projectId, templateId: templateId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// 僅更新 hub（樣板列表預載結構用）；保留已快取之紀錄列表與分頁 meta，避免覆蓋第二層資料。
    static func mergeHub(
        projectId: String,
        templateId: String,
        hub: SelfInspectionTemplateHubDTO
    ) {
        let existing = load(projectId: projectId, templateId: templateId)
        save(
            projectId: projectId,
            templateId: templateId,
            hub: hub,
            records: existing?.records ?? [],
            meta: existing?.meta
        )
    }

    static func removeAllFiles() {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        guard let items = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }
}
