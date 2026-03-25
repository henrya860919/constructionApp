//
//  FieldOutboxStore.swift
//  constructionApp
//

import Foundation
import Observation
import UserNotifications

// MARK: - Index

enum FieldOutboxKind: String, Codable, Sendable {
    case repairCreate
    case repairRecordCreate
    case defectCreate
    case defectRecordCreate
    case selfInspectionRecordCreate
}

struct FieldOutboxIndexRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var projectId: String
    var kind: FieldOutboxKind
    /// 需先完成之項目（例如離線新增報修後再新增紀錄）。
    var dependsOn: UUID?
    var title: String
    var templateId: String?
    /// 已存在於伺服器之報修 id（新增紀錄用）。
    var repairId: String?
    var defectId: String?
}

// MARK: - Payloads（entries/<id>/payload.json）

struct FieldOutboxMediaFile: Codable, Sendable {
    var storedName: String
    var uploadFileName: String
    var mimeType: String
    var category: String
}

struct FieldOutboxRepairCreatePayload: Codable, Sendable {
    var customerName: String
    var contactPhone: String
    var repairContent: String
    var problemCategory: String
    var isSecondRepair: Bool
    var status: String
    var unitLabel: String?
    var remarks: String?
    var deliveryDate: String?
    var repairDate: String?
    var photos: [FieldOutboxMediaFile]
    var attachments: [FieldOutboxMediaFile]
}

struct FieldOutboxRepairRecordPayload: Codable, Sendable {
    /// 若為已存在報修，直接帶伺服器 id。
    var repairId: String?
    var dependsOnRepairOutboxId: UUID?
    var content: String
    var photos: [FieldOutboxMediaFile]
}

struct FieldOutboxDefectCreatePayload: Codable, Sendable {
    var description: String
    var discoveredBy: String
    var priority: String
    var floor: String?
    var location: String?
    var status: String
    var photos: [FieldOutboxMediaFile]
}

struct FieldOutboxDefectRecordPayload: Codable, Sendable {
    var defectId: String?
    var dependsOnDefectOutboxId: UUID?
    var content: String
    var photos: [FieldOutboxMediaFile]
}

struct FieldOutboxSelfInspectionPayload: Codable, Sendable {
    var templateId: String
    /// 僅含已上傳之 photo id；新照片另列於 newPhotos。
    var baseBody: SelfInspectionCreateRecordBody
    var newPhotos: [FieldOutboxMediaFile]
}

// MARK: - Store

@MainActor
@Observable
final class FieldOutboxStore {
    static let shared = FieldOutboxStore()

    private(set) var records: [FieldOutboxIndexRecord] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fm = FileManager.default

    private var rootURL: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("FieldOutbox", isDirectory: true)
    }

    private var indexURL: URL { rootURL.appendingPathComponent("index.json") }

    private init() {
        reloadFromDisk()
    }

    func reloadFromDisk() {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? decoder.decode([FieldOutboxIndexRecord].self, from: data) else {
            records = []
            return
        }
        records = list.sorted { $0.createdAt < $1.createdAt }
    }

    private func saveIndex() throws {
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let data = try encoder.encode(records)
        try data.write(to: indexURL, options: .atomic)
    }

    private func entryDir(_ id: UUID) -> URL {
        rootURL.appendingPathComponent("entries", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func mediaDir(_ id: UUID) -> URL {
        entryDir(id).appendingPathComponent("media", isDirectory: true)
    }

    func records(forProjectId projectId: String) -> [FieldOutboxIndexRecord] {
        records.filter { $0.projectId == projectId }
    }

    func pendingCount(forProjectId projectId: String) -> Int {
        records(forProjectId: projectId).count
    }

    // MARK: - Enqueue

    func enqueueRepairCreate(
        projectId: String,
        title: String,
        payload: FieldOutboxRepairCreatePayload,
        mediaData: [String: Data]
    ) throws {
        let id = UUID()
        let dir = entryDir(id)
        let mdir = mediaDir(id)
        try fm.createDirectory(at: mdir, withIntermediateDirectories: true)
        for (name, data) in mediaData {
            try data.write(to: mdir.appendingPathComponent(name), options: .atomic)
        }
        let payloadData = try encoder.encode(payload)
        try payloadData.write(to: dir.appendingPathComponent("payload.json"), options: .atomic)

        let rec = FieldOutboxIndexRecord(
            id: id,
            createdAt: Date(),
            projectId: projectId,
            kind: .repairCreate,
            dependsOn: nil,
            title: title,
            templateId: nil,
            repairId: nil,
            defectId: nil
        )
        records.append(rec)
        try saveIndex()
        NotificationCenter.default.post(name: .fieldOutboxDidChange, object: nil)
    }

    func enqueueRepairRecord(
        projectId: String,
        title: String,
        repairId: String?,
        dependsOnRepairOutboxId: UUID?,
        payload: FieldOutboxRepairRecordPayload,
        mediaData: [String: Data]
    ) throws {
        let id = UUID()
        let dep: UUID? = dependsOnRepairOutboxId
        let dir = entryDir(id)
        let mdir = mediaDir(id)
        try fm.createDirectory(at: mdir, withIntermediateDirectories: true)
        for (name, data) in mediaData {
            try data.write(to: mdir.appendingPathComponent(name), options: .atomic)
        }
        let payloadData = try encoder.encode(payload)
        try payloadData.write(to: dir.appendingPathComponent("payload.json"), options: .atomic)

        let rec = FieldOutboxIndexRecord(
            id: id,
            createdAt: Date(),
            projectId: projectId,
            kind: .repairRecordCreate,
            dependsOn: dep,
            title: title,
            templateId: nil,
            repairId: repairId,
            defectId: nil
        )
        records.append(rec)
        try saveIndex()
        NotificationCenter.default.post(name: .fieldOutboxDidChange, object: nil)
    }

    func enqueueDefectCreate(
        projectId: String,
        title: String,
        payload: FieldOutboxDefectCreatePayload,
        mediaData: [String: Data]
    ) throws {
        let id = UUID()
        let dir = entryDir(id)
        let mdir = mediaDir(id)
        try fm.createDirectory(at: mdir, withIntermediateDirectories: true)
        for (name, data) in mediaData {
            try data.write(to: mdir.appendingPathComponent(name), options: .atomic)
        }
        let payloadData = try encoder.encode(payload)
        try payloadData.write(to: dir.appendingPathComponent("payload.json"), options: .atomic)

        let rec = FieldOutboxIndexRecord(
            id: id,
            createdAt: Date(),
            projectId: projectId,
            kind: .defectCreate,
            dependsOn: nil,
            title: title,
            templateId: nil,
            repairId: nil,
            defectId: nil
        )
        records.append(rec)
        try saveIndex()
        NotificationCenter.default.post(name: .fieldOutboxDidChange, object: nil)
    }

    func enqueueDefectRecord(
        projectId: String,
        title: String,
        defectId: String?,
        dependsOnDefectOutboxId: UUID?,
        payload: FieldOutboxDefectRecordPayload,
        mediaData: [String: Data]
    ) throws {
        let id = UUID()
        let dir = entryDir(id)
        let mdir = mediaDir(id)
        try fm.createDirectory(at: mdir, withIntermediateDirectories: true)
        for (name, data) in mediaData {
            try data.write(to: mdir.appendingPathComponent(name), options: .atomic)
        }
        let payloadData = try encoder.encode(payload)
        try payloadData.write(to: dir.appendingPathComponent("payload.json"), options: .atomic)

        let rec = FieldOutboxIndexRecord(
            id: id,
            createdAt: Date(),
            projectId: projectId,
            kind: .defectRecordCreate,
            dependsOn: dependsOnDefectOutboxId,
            title: title,
            templateId: nil,
            repairId: nil,
            defectId: defectId
        )
        records.append(rec)
        try saveIndex()
        NotificationCenter.default.post(name: .fieldOutboxDidChange, object: nil)
    }

    func enqueueSelfInspectionRecord(
        projectId: String,
        templateId: String,
        title: String,
        payload: FieldOutboxSelfInspectionPayload,
        mediaData: [String: Data]
    ) throws {
        let id = UUID()
        let dir = entryDir(id)
        let mdir = mediaDir(id)
        try fm.createDirectory(at: mdir, withIntermediateDirectories: true)
        for (name, data) in mediaData {
            try data.write(to: mdir.appendingPathComponent(name), options: .atomic)
        }
        let payloadData = try encoder.encode(payload)
        try payloadData.write(to: dir.appendingPathComponent("payload.json"), options: .atomic)

        let rec = FieldOutboxIndexRecord(
            id: id,
            createdAt: Date(),
            projectId: projectId,
            kind: .selfInspectionRecordCreate,
            dependsOn: nil,
            title: title,
            templateId: templateId,
            repairId: nil,
            defectId: nil
        )
        records.append(rec)
        try saveIndex()
        NotificationCenter.default.post(name: .fieldOutboxDidChange, object: nil)
    }

    // MARK: - Remove

    func removeEntry(id: UUID) throws {
        records.removeAll { $0.id == id }
        try saveIndex()
        let dir = entryDir(id)
        try? fm.removeItem(at: dir)
        NotificationCenter.default.post(name: .fieldOutboxDidChange, object: nil)
    }

    // MARK: - Sync

    /// 上傳佇列中的項目；成功則自佇列移除。401 時中止。
    /// - Returns: 本次成功送出的佇列筆數、開始時是否有待傳項目、結束時佇列是否已空。
    @discardableResult
    func syncOutbox(baseURL: URL, token: String) async -> (removedCount: Int, hadPendingAtStart: Bool, queueNowEmpty: Bool) {
        let hadPendingAtStart = !records.isEmpty
        guard FieldNetworkMonitor.shared.isReachable else {
            return (0, hadPendingAtStart, records.isEmpty)
        }
        var removedCount = 0
        var idMap: [UUID: String] = [:]
        var progressed = true
        while progressed {
            progressed = false
            let snapshot = records.sorted { $0.createdAt < $1.createdAt }
            for rec in snapshot {
                guard records.contains(where: { $0.id == rec.id }) else { continue }
                if let dep = rec.dependsOn, idMap[dep] == nil {
                    continue
                }
                do {
                    switch rec.kind {
                    case .repairCreate:
                        let dto = try await executeRepairCreate(rec: rec, baseURL: baseURL, token: token)
                        idMap[rec.id] = dto.id
                        try removeEntry(id: rec.id)
                        removedCount += 1
                        progressed = true
                    case .repairRecordCreate:
                        let rid = try resolveRepairId(rec: rec, idMap: idMap)
                        try await executeRepairRecord(rec: rec, repairId: rid, baseURL: baseURL, token: token)
                        try removeEntry(id: rec.id)
                        removedCount += 1
                        progressed = true
                    case .defectCreate:
                        let dto = try await executeDefectCreate(rec: rec, baseURL: baseURL, token: token)
                        idMap[rec.id] = dto.id
                        try removeEntry(id: rec.id)
                        removedCount += 1
                        progressed = true
                    case .defectRecordCreate:
                        let did = try resolveDefectId(rec: rec, idMap: idMap)
                        try await executeDefectRecord(rec: rec, defectId: did, baseURL: baseURL, token: token)
                        try removeEntry(id: rec.id)
                        removedCount += 1
                        progressed = true
                    case .selfInspectionRecordCreate:
                        try await executeSelfInspection(rec: rec, baseURL: baseURL, token: token)
                        try removeEntry(id: rec.id)
                        removedCount += 1
                        progressed = true
                    }
                } catch let api as APIRequestError {
                    if case let .httpStatus(code, _) = api, code == 401 {
                        return (removedCount, hadPendingAtStart, records.isEmpty)
                    }
                } catch {
                    continue
                }
            }
        }
        let queueNowEmpty = records.isEmpty
        if hadPendingAtStart, queueNowEmpty {
            await FieldOutboxSyncNotifier.notifyAllSynced()
        }
        return (removedCount, hadPendingAtStart, queueNowEmpty)
    }

    // MARK: - Execute steps

    private func loadPayload<T: Decodable>(_ type: T.Type, rec: FieldOutboxIndexRecord) throws -> T {
        let url = entryDir(rec.id).appendingPathComponent("payload.json")
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func readMedia(_ rec: FieldOutboxIndexRecord, storedName: String) throws -> Data {
        try Data(contentsOf: mediaDir(rec.id).appendingPathComponent(storedName))
    }

    private func uploadMedia(
        baseURL: URL,
        token: String,
        projectId: String,
        rec: FieldOutboxIndexRecord,
        files: [FieldOutboxMediaFile]
    ) async throws -> [String] {
        var ids: [String] = []
        for f in files {
            let data = try readMedia(rec, storedName: f.storedName)
            let up = try await APIService.uploadProjectFile(
                baseURL: baseURL,
                token: token,
                projectId: projectId,
                fileData: data,
                fileName: f.uploadFileName,
                mimeType: f.mimeType,
                category: f.category
            )
            ids.append(up.id)
        }
        return ids
    }

    private func executeRepairCreate(rec: FieldOutboxIndexRecord, baseURL: URL, token: String) async throws -> RepairListItemDTO {
        let p: FieldOutboxRepairCreatePayload = try loadPayload(FieldOutboxRepairCreatePayload.self, rec: rec)
        let photoIds = try await uploadMedia(baseURL: baseURL, token: token, projectId: rec.projectId, rec: rec, files: p.photos)
        let fileIds = try await uploadMedia(baseURL: baseURL, token: token, projectId: rec.projectId, rec: rec, files: p.attachments)
        let body = CreateRepairRequestBody(
            customerName: p.customerName,
            contactPhone: p.contactPhone,
            repairContent: p.repairContent,
            problemCategory: p.problemCategory,
            isSecondRepair: p.isSecondRepair,
            status: p.status,
            unitLabel: p.unitLabel,
            remarks: p.remarks,
            deliveryDate: p.deliveryDate,
            repairDate: p.repairDate,
            photoAttachmentIds: photoIds.isEmpty ? nil : photoIds,
            fileAttachmentIds: fileIds.isEmpty ? nil : fileIds
        )
        return try await APIService.createRepairRequest(
            baseURL: baseURL,
            token: token,
            projectId: rec.projectId,
            body: body
        )
    }

    private func resolveRepairId(rec: FieldOutboxIndexRecord, idMap: [UUID: String]) throws -> String {
        if let rid = rec.repairId, !rid.isEmpty { return rid }
        if let dep = rec.dependsOn, let mapped = idMap[dep] { return mapped }
        throw APIRequestError.invalidURL
    }

    private func executeRepairRecord(rec: FieldOutboxIndexRecord, repairId: String, baseURL: URL, token: String) async throws {
        let p: FieldOutboxRepairRecordPayload = try loadPayload(FieldOutboxRepairRecordPayload.self, rec: rec)
        let ids = try await uploadMedia(baseURL: baseURL, token: token, projectId: rec.projectId, rec: rec, files: p.photos)
        let body = CreateRepairExecutionRecordBody(content: p.content, attachmentIds: ids)
        _ = try await APIService.createRepairExecutionRecord(
            baseURL: baseURL,
            token: token,
            projectId: rec.projectId,
            repairId: repairId,
            body: body
        )
    }

    private func executeDefectCreate(rec: FieldOutboxIndexRecord, baseURL: URL, token: String) async throws -> DefectListItemDTO {
        let p: FieldOutboxDefectCreatePayload = try loadPayload(FieldOutboxDefectCreatePayload.self, rec: rec)
        let attachmentIds = try await uploadMedia(baseURL: baseURL, token: token, projectId: rec.projectId, rec: rec, files: p.photos)
        let body = CreateDefectImprovementBody(
            description: p.description,
            discoveredBy: p.discoveredBy,
            priority: p.priority,
            floor: p.floor,
            location: p.location,
            status: p.status,
            attachmentIds: attachmentIds
        )
        return try await APIService.createDefectImprovement(
            baseURL: baseURL,
            token: token,
            projectId: rec.projectId,
            body: body
        )
    }

    private func resolveDefectId(rec: FieldOutboxIndexRecord, idMap: [UUID: String]) throws -> String {
        if let did = rec.defectId, !did.isEmpty { return did }
        if let dep = rec.dependsOn, let mapped = idMap[dep] { return mapped }
        throw APIRequestError.invalidURL
    }

    private func executeDefectRecord(rec: FieldOutboxIndexRecord, defectId: String, baseURL: URL, token: String) async throws {
        let p: FieldOutboxDefectRecordPayload = try loadPayload(FieldOutboxDefectRecordPayload.self, rec: rec)
        let ids = try await uploadMedia(baseURL: baseURL, token: token, projectId: rec.projectId, rec: rec, files: p.photos)
        let body = CreateDefectExecutionRecordBody(content: p.content, attachmentIds: ids)
        _ = try await APIService.createDefectExecutionRecord(
            baseURL: baseURL,
            token: token,
            projectId: rec.projectId,
            defectId: defectId,
            body: body
        )
    }

    private func executeSelfInspection(rec: FieldOutboxIndexRecord, baseURL: URL, token: String) async throws {
        guard let templateId = rec.templateId, !templateId.isEmpty else { throw APIRequestError.invalidURL }
        let p: FieldOutboxSelfInspectionPayload = try loadPayload(FieldOutboxSelfInspectionPayload.self, rec: rec)
        var newUploaded: [String] = []
        if !p.newPhotos.isEmpty {
            newUploaded = try await uploadMedia(
                baseURL: baseURL,
                token: token,
                projectId: rec.projectId,
                rec: rec,
                files: p.newPhotos
            )
        }
        let old = p.baseBody.filledPayload
        let existing = old.photoAttachmentIds ?? []
        let merged = fieldOutboxUniqIdsPreservingOrder(existing + newUploaded)
        let mergedPayload = SelfInspectionFilledPayloadEncodable(
            header: old.header,
            items: old.items,
            photoAttachmentIds: merged.isEmpty ? nil : merged
        )
        let body = SelfInspectionCreateRecordBody(filledPayload: mergedPayload)
        _ = try await APIService.createSelfInspectionRecord(
            baseURL: baseURL,
            token: token,
            projectId: rec.projectId,
            templateId: templateId,
            body: body
        )
    }
}

private func fieldOutboxUniqIdsPreservingOrder(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for id in ids where seen.insert(id).inserted {
        out.append(id)
    }
    return out
}

extension Notification.Name {
    static let fieldOutboxDidChange = Notification.Name("FieldOutbox.didChange")
    /// 應重新向伺服器載入列表（例如同步完成或網路恢復）。
    static let fieldRemoteDataShouldRefresh = Notification.Name("FieldRemoteData.shouldRefresh")
}

// MARK: - 同步完成通知

private enum FieldOutboxSyncNotifier {
    static var didRequestAuth = false

    @MainActor
    static func notifyAllSynced() async {
        let center = UNUserNotificationCenter.current()
        if !didRequestAuth {
            didRequestAuth = true
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        await FieldRemoteNotifications.registerWithAPNsIfAuthorized()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "同步完成"
        content.body = "待上傳項目已全部送達伺服器。"
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(req)
    }
}
