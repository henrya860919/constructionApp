//
//  FieldDailyLogLocalStore.swift
//  constructionApp
//
//  施工日誌草稿：依專案存在 UserDefaults（之後可改接 API）。
//

import Foundation
import Observation

/// 施工日誌工項：與網頁 `WorkDraft`／PCCES 選擇器對齊（`pccesItemId` + 本日完成量）。
struct FieldDailyLogWorkItem: Codable, Equatable, Identifiable {
    var pccesItemId: String
    var itemNo: String
    var workItemName: String
    var unit: String
    var contractQty: String
    var unitPrice: String?
    var pccesItemKind: String?
    /// 對應網頁 `dailyQty`（本日完成量）；選工項畫面不填，回編輯頁再填。
    var dailyQty: String

    var id: String { pccesItemId }

    enum CodingKeys: String, CodingKey {
        case pccesItemId, itemNo, workItemName, unit, contractQty, unitPrice, pccesItemKind, dailyQty
        case legacyWbsNodeId = "wbsNodeId"
        case legacyCode = "code"
        case legacyName = "name"
        case legacyAmountText = "amountText"
    }

    init(
        pccesItemId: String,
        itemNo: String,
        workItemName: String,
        unit: String,
        contractQty: String,
        unitPrice: String?,
        pccesItemKind: String?,
        dailyQty: String
    ) {
        self.pccesItemId = pccesItemId
        self.itemNo = itemNo
        self.workItemName = workItemName
        self.unit = unit
        self.contractQty = contractQty
        self.unitPrice = unitPrice
        self.pccesItemKind = pccesItemKind
        self.dailyQty = dailyQty
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let pid = try c.decodeIfPresent(String.self, forKey: .pccesItemId), !pid.isEmpty {
            pccesItemId = pid
            itemNo = try c.decodeIfPresent(String.self, forKey: .itemNo) ?? ""
            workItemName = try c.decodeIfPresent(String.self, forKey: .workItemName) ?? ""
            unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
            contractQty = try c.decodeIfPresent(String.self, forKey: .contractQty) ?? ""
            unitPrice = try c.decodeIfPresent(String.self, forKey: .unitPrice)
            pccesItemKind = try c.decodeIfPresent(String.self, forKey: .pccesItemKind)
            dailyQty = try c.decodeIfPresent(String.self, forKey: .dailyQty) ?? ""
        } else if let wbs = try c.decodeIfPresent(String.self, forKey: .legacyWbsNodeId), !wbs.isEmpty {
            // 舊版 WBS 草稿：僅供顯示／刪除，無法與 PCCES 選擇器狀態同步。
            pccesItemId = "legacy-wbs:\(wbs)"
            itemNo = try c.decodeIfPresent(String.self, forKey: .legacyCode) ?? ""
            workItemName = try c.decodeIfPresent(String.self, forKey: .legacyName) ?? ""
            unit = ""
            contractQty = ""
            unitPrice = nil
            pccesItemKind = nil
            dailyQty = try c.decodeIfPresent(String.self, forKey: .legacyAmountText) ?? ""
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: c.codingPath, debugDescription: "無效的施工項目列")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pccesItemId, forKey: .pccesItemId)
        try c.encode(itemNo, forKey: .itemNo)
        try c.encode(workItemName, forKey: .workItemName)
        try c.encode(unit, forKey: .unit)
        try c.encode(contractQty, forKey: .contractQty)
        try c.encodeIfPresent(unitPrice, forKey: .unitPrice)
        try c.encodeIfPresent(pccesItemKind, forKey: .pccesItemKind)
        try c.encode(dailyQty, forKey: .dailyQty)
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

    static let empty = FieldDailyLogPersistedDay(weatherRaw: nil, notes: "", workItems: [], materials: [], personnelRows: [])

    enum CodingKeys: String, CodingKey {
        case weatherRaw
        case notes
        case workItems
        case materials
        case personnelRows
    }

    init(
        weatherRaw: String?,
        notes: String,
        workItems: [FieldDailyLogWorkItem] = [],
        materials: [FieldDailyLogMaterialRow] = [],
        personnelRows: [FieldDailyLogPersonnelEquipmentRow] = []
    ) {
        self.weatherRaw = weatherRaw
        self.notes = notes
        self.workItems = workItems
        self.materials = materials
        self.personnelRows = personnelRows
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weatherRaw = try c.decodeIfPresent(String.self, forKey: .weatherRaw)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        workItems = try c.decodeIfPresent([FieldDailyLogWorkItem].self, forKey: .workItems) ?? []
        materials = try c.decodeIfPresent([FieldDailyLogMaterialRow].self, forKey: .materials) ?? []
        personnelRows = try c.decodeIfPresent([FieldDailyLogPersonnelEquipmentRow].self, forKey: .personnelRows) ?? []
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
