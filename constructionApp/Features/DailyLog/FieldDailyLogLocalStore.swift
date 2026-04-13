//
//  FieldDailyLogLocalStore.swift
//  constructionApp
//
//  施工日誌：依專案存在 UserDefaults 作快取，並與後端 `construction-daily-logs` 同步。
//

import Foundation
import Observation

/// 施工日誌工項：與網頁 `WorkDraft`／API 對齊（可選 `pccesItemId` 手填列）。
struct FieldDailyLogWorkItem: Codable, Equatable, Identifiable {
    /// 列穩定 id（PCCES 列通常等於 `pccesItemId`；手填列為 `m:uuid`）。
    var id: String
    var pccesItemId: String?
    var itemNo: String
    var workItemName: String
    var unit: String
    var contractQty: String
    var unitPrice: String?
    var pccesItemKind: String?
    /// 對應網頁 `dailyQty`（本日完成量）。
    var dailyQty: String
    /// 與 API 一致；綁定 PCCES 時後端會重算，送出可填 "0"。
    var accumulatedQty: String
    var remark: String

    enum CodingKeys: String, CodingKey {
        case id, pccesItemId, itemNo, workItemName, unit, contractQty, unitPrice, pccesItemKind, dailyQty, accumulatedQty, remark
        case legacyWbsNodeId = "wbsNodeId"
        case legacyCode = "code"
        case legacyName = "name"
        case legacyAmountText = "amountText"
    }

    init(
        id: String,
        pccesItemId: String?,
        itemNo: String,
        workItemName: String,
        unit: String,
        contractQty: String,
        unitPrice: String?,
        pccesItemKind: String?,
        dailyQty: String,
        accumulatedQty: String = "0",
        remark: String = ""
    ) {
        self.id = id
        self.pccesItemId = pccesItemId
        self.itemNo = itemNo
        self.workItemName = workItemName
        self.unit = unit
        self.contractQty = contractQty
        self.unitPrice = unitPrice
        self.pccesItemKind = pccesItemKind
        self.dailyQty = dailyQty
        self.accumulatedQty = accumulatedQty
        self.remark = remark
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let rowId = try c.decodeIfPresent(String.self, forKey: .id), !rowId.isEmpty {
            id = rowId
            pccesItemId = try c.decodeIfPresent(String.self, forKey: .pccesItemId).flatMap { $0.isEmpty ? nil : $0 }
            itemNo = try c.decodeIfPresent(String.self, forKey: .itemNo) ?? ""
            workItemName = try c.decodeIfPresent(String.self, forKey: .workItemName) ?? ""
            unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
            contractQty = try c.decodeIfPresent(String.self, forKey: .contractQty) ?? ""
            unitPrice = try c.decodeIfPresent(String.self, forKey: .unitPrice)
            pccesItemKind = try c.decodeIfPresent(String.self, forKey: .pccesItemKind)
            dailyQty = try c.decodeIfPresent(String.self, forKey: .dailyQty) ?? ""
            accumulatedQty = try c.decodeIfPresent(String.self, forKey: .accumulatedQty) ?? "0"
            remark = try c.decodeIfPresent(String.self, forKey: .remark) ?? ""
            return
        }
        if let pid = try c.decodeIfPresent(String.self, forKey: .pccesItemId), !pid.isEmpty {
            id = pid
            pccesItemId = pid
            itemNo = try c.decodeIfPresent(String.self, forKey: .itemNo) ?? ""
            workItemName = try c.decodeIfPresent(String.self, forKey: .workItemName) ?? ""
            unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
            contractQty = try c.decodeIfPresent(String.self, forKey: .contractQty) ?? ""
            unitPrice = try c.decodeIfPresent(String.self, forKey: .unitPrice)
            pccesItemKind = try c.decodeIfPresent(String.self, forKey: .pccesItemKind)
            dailyQty = try c.decodeIfPresent(String.self, forKey: .dailyQty) ?? ""
            accumulatedQty = try c.decodeIfPresent(String.self, forKey: .accumulatedQty) ?? "0"
            remark = try c.decodeIfPresent(String.self, forKey: .remark) ?? ""
            return
        }
        if let wbs = try c.decodeIfPresent(String.self, forKey: .legacyWbsNodeId), !wbs.isEmpty {
            let legacyId = "legacy-wbs:\(wbs)"
            id = legacyId
            pccesItemId = legacyId // 非真實 PCCES id，僅供舊草稿辨識
            itemNo = try c.decodeIfPresent(String.self, forKey: .legacyCode) ?? ""
            workItemName = try c.decodeIfPresent(String.self, forKey: .legacyName) ?? ""
            unit = ""
            contractQty = ""
            unitPrice = nil
            pccesItemKind = nil
            dailyQty = try c.decodeIfPresent(String.self, forKey: .legacyAmountText) ?? ""
            accumulatedQty = "0"
            remark = ""
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: c.codingPath, debugDescription: "無效的施工項目列")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(pccesItemId, forKey: .pccesItemId)
        try c.encode(itemNo, forKey: .itemNo)
        try c.encode(workItemName, forKey: .workItemName)
        try c.encode(unit, forKey: .unit)
        try c.encode(contractQty, forKey: .contractQty)
        try c.encodeIfPresent(unitPrice, forKey: .unitPrice)
        try c.encodeIfPresent(pccesItemKind, forKey: .pccesItemKind)
        try c.encode(dailyQty, forKey: .dailyQty)
        try c.encode(accumulatedQty, forKey: .accumulatedQty)
        try c.encode(remark, forKey: .remark)
    }
}

/// 施工日誌「人員／機具」列：對齊網頁 `PeDraft`／API `personnelEquipmentRows`。
struct FieldDailyLogPersonnelEquipmentRow: Codable, Equatable, Identifiable {
    var id: String
    var projectResourceId: String?
    var resourceType: String?
    var unit: String
    var workType: String
    var dailyWorkers: String
    var accumulatedWorkers: String
    var equipmentName: String
    var dailyEquipmentQty: String
    var accumulatedEquipmentQty: String

    static func emptyManualRow() -> FieldDailyLogPersonnelEquipmentRow {
        FieldDailyLogPersonnelEquipmentRow(
            id: "m:\(UUID().uuidString)",
            projectResourceId: nil,
            resourceType: nil,
            unit: "",
            workType: "",
            dailyWorkers: "0",
            accumulatedWorkers: "0",
            equipmentName: "",
            dailyEquipmentQty: "0",
            accumulatedEquipmentQty: "0"
        )
    }

    static func fromServer(_ d: ConstructionDailyLogPersonnelRowDTO) -> FieldDailyLogPersonnelEquipmentRow {
        let rid: String? = {
            guard let s = d.projectResourceId else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()
        let equipTrimmed = d.equipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rowId: String
        if let rid {
            rowId = "r:\(rid)"
        } else if let sid = d.id, !sid.isEmpty {
            rowId = "row:\(sid)"
        } else {
            rowId = "m:\(UUID().uuidString)"
        }
        return FieldDailyLogPersonnelEquipmentRow(
            id: rowId,
            projectResourceId: rid,
            resourceType: rid != nil ? (equipTrimmed.isEmpty ? "labor" : "equipment") : nil,
            unit: "",
            workType: d.workType,
            dailyWorkers: String(d.dailyWorkers),
            accumulatedWorkers: String(d.accumulatedWorkers),
            equipmentName: d.equipmentName,
            dailyEquipmentQty: d.dailyEquipmentQty,
            accumulatedEquipmentQty: d.accumulatedEquipmentQty
        )
    }
}

/// 施工日誌材料列：對齊網頁 `MatDraft`／API `materials`。
struct FieldDailyLogMaterialRow: Codable, Equatable, Identifiable {
    var id: String
    var projectResourceId: String?
    var materialName: String
    var unit: String
    var contractQty: String
    var dailyUsedQty: String
    var accumulatedQty: String
    var remark: String

    static func fromProjectResource(resourceId: String, name: String, unit: String, priorQty: String) -> FieldDailyLogMaterialRow {
        let prior = FieldDailyLogPersonnelReconcile.parseDecimalString(priorQty)
        return FieldDailyLogMaterialRow(
            id: "r:\(resourceId)",
            projectResourceId: resourceId,
            materialName: name,
            unit: unit,
            contractQty: "0",
            dailyUsedQty: "0",
            accumulatedQty: FieldDailyLogPersonnelReconcile.formatDecimal(prior),
            remark: ""
        )
    }

    /// 自後端 GET 明細轉成本地列。
    static func fromServer(_ d: ConstructionDailyLogMaterialRowDTO) -> FieldDailyLogMaterialRow {
        let rid: String? = {
            guard let s = d.projectResourceId else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()
        let rowId: String
        if let rid {
            rowId = "r:\(rid)"
        } else if let sid = d.id, !sid.isEmpty {
            rowId = "row:\(sid)"
        } else {
            rowId = "m:\(UUID().uuidString)"
        }
        return FieldDailyLogMaterialRow(
            id: rowId,
            projectResourceId: rid,
            materialName: d.materialName,
            unit: d.unit,
            contractQty: d.contractQty,
            dailyUsedQty: d.dailyUsedQty,
            accumulatedQty: d.accumulatedQty,
            remark: d.remark
        )
    }

    static func emptyManual() -> FieldDailyLogMaterialRow {
        FieldDailyLogMaterialRow(
            id: "m:\(UUID().uuidString)",
            projectResourceId: nil,
            materialName: "",
            unit: "",
            contractQty: "0",
            dailyUsedQty: "0",
            accumulatedQty: "0",
            remark: ""
        )
    }
}

struct FieldDailyLogPersistedDay: Codable, Equatable {
    var weatherRaw: String?
    var notes: String
    var workItems: [FieldDailyLogWorkItem]
    var materials: [FieldDailyLogMaterialRow]
    var personnelRows: [FieldDailyLogPersonnelEquipmentRow]
    /// 後端日誌 id（`GET/PATCH .../construction-daily-logs/:id`）；新建成功後寫入。
    var remoteLogId: String?

    static let empty = FieldDailyLogPersistedDay(
        weatherRaw: nil,
        notes: "",
        workItems: [],
        materials: [],
        personnelRows: [],
        remoteLogId: nil
    )

    enum CodingKeys: String, CodingKey {
        case weatherRaw
        case notes
        case workItems
        case materials
        case personnelRows
        case remoteLogId
    }

    init(
        weatherRaw: String?,
        notes: String,
        workItems: [FieldDailyLogWorkItem] = [],
        materials: [FieldDailyLogMaterialRow] = [],
        personnelRows: [FieldDailyLogPersonnelEquipmentRow] = [],
        remoteLogId: String? = nil
    ) {
        self.weatherRaw = weatherRaw
        self.notes = notes
        self.workItems = workItems
        self.materials = materials
        self.personnelRows = personnelRows
        self.remoteLogId = remoteLogId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weatherRaw = try c.decodeIfPresent(String.self, forKey: .weatherRaw)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        workItems = try c.decodeIfPresent([FieldDailyLogWorkItem].self, forKey: .workItems) ?? []
        materials = try c.decodeIfPresent([FieldDailyLogMaterialRow].self, forKey: .materials) ?? []
        personnelRows = try c.decodeIfPresent([FieldDailyLogPersonnelEquipmentRow].self, forKey: .personnelRows) ?? []
        remoteLogId = try c.decodeIfPresent(String.self, forKey: .remoteLogId)
    }
}

@MainActor
@Observable
final class FieldDailyLogLocalStore {
    private let defaults: UserDefaults
    private var byDay: [String: FieldDailyLogPersistedDay] = [:]
    /// 最後一次成功寫入磁碟的快照（用於判斷是否有未儲存變更）
    private var lastWritten: [String: FieldDailyLogPersistedDay] = [:]
    private(set) var projectId: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activateProject(_ id: String) {
        guard projectId != id else { return }
        projectId = id
        byDay = Self.readMap(defaults: defaults, projectId: id)
        lastWritten = byDay
    }

    func day(for key: String) -> FieldDailyLogPersistedDay {
        byDay[key] ?? .empty
    }

    func setDay(_ key: String, value: FieldDailyLogPersistedDay) {
        byDay[key] = value
    }

    func isDirty(dayKey: String) -> Bool {
        let cur = byDay[dayKey] ?? .empty
        let saved = lastWritten[dayKey] ?? .empty
        return cur != saved
    }

    func save(dayKey: String) {
        guard let pid = projectId else { return }
        lastWritten[dayKey] = byDay[dayKey] ?? .empty
        Self.writeMap(defaults: defaults, projectId: pid, map: byDay)
    }

    /// 捨棄目前草稿，還原成上次成功 `save` 的內容（僅記憶體；若從未儲存過則清空該日）。
    func revertToLastSaved(dayKey: String) {
        byDay[dayKey] = lastWritten[dayKey] ?? .empty
    }

    private static func storageKey(projectId: String) -> String {
        "field.constructionDailyLog.v1.\(projectId)"
    }

    private static func readMap(defaults: UserDefaults, projectId: String) -> [String: FieldDailyLogPersistedDay] {
        let key = storageKey(projectId: projectId)
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: FieldDailyLogPersistedDay].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func writeMap(defaults: UserDefaults, projectId: String, map: [String: FieldDailyLogPersistedDay]) {
        let key = storageKey(projectId: projectId)
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: key)
    }
}

extension FieldDailyLogWorkItem {
    static func fromServer(_ d: ConstructionDailyLogWorkItemDTO) -> FieldDailyLogWorkItem {
        let pid: String? = {
            guard let s = d.pccesItemId else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()
        let rowId: String
        if let pid {
            rowId = pid
        } else if let sid = d.id, !sid.isEmpty {
            rowId = "wi:\(sid)"
        } else {
            rowId = "wi:m:\(UUID().uuidString)"
        }
        return FieldDailyLogWorkItem(
            id: rowId,
            pccesItemId: pid,
            itemNo: d.itemNo ?? "",
            workItemName: d.workItemName,
            unit: d.unit,
            contractQty: d.contractQty,
            unitPrice: d.unitPrice,
            pccesItemKind: d.pccesItemKind,
            dailyQty: d.dailyQty,
            accumulatedQty: d.accumulatedQty,
            remark: d.remark
        )
    }
}
