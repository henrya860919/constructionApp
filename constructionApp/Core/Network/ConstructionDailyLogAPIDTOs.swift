//
//  ConstructionDailyLogAPIDTOs.swift
//  constructionApp
//
//  對齊後端 `construction-daily-logs` 與網頁 `src/api/construction-daily-logs.ts`。
//

import Foundation

// MARK: - List

struct ConstructionDailyLogListMetaDTO: Decodable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
}

struct ConstructionDailyLogListItemDTO: Decodable, Sendable {
    let id: String
    let logDate: String
}

struct ConstructionDailyLogListEnvelope: Decodable, Sendable {
    let data: [ConstructionDailyLogListItemDTO]
    let meta: ConstructionDailyLogListMetaDTO
}

// MARK: - Detail (GET by id)

struct ConstructionDailyLogWorkItemDTO: Decodable, Sendable {
    let id: String?
    let pccesItemId: String?
    let itemNo: String?
    let pccesItemKind: String?
    let pccesStructuralLeaf: Bool?
    let workItemName: String
    let unit: String
    let contractQty: String
    let unitPrice: String?
    let dailyQty: String
    let accumulatedQty: String
    let remark: String
}

struct ConstructionDailyLogMaterialRowDTO: Decodable, Sendable {
    let id: String?
    let projectResourceId: String?
    let materialName: String
    let unit: String
    let contractQty: String
    let dailyUsedQty: String
    let accumulatedQty: String
    let remark: String
}

struct ConstructionDailyLogPersonnelRowDTO: Decodable, Sendable {
    let id: String?
    let projectResourceId: String?
    let workType: String
    let dailyWorkers: Int
    let accumulatedWorkers: Int
    let equipmentName: String
    let dailyEquipmentQty: String
    let accumulatedEquipmentQty: String
}

struct ConstructionDailyLogDetailDTO: Decodable, Sendable {
    let id: String
    let projectId: String
    let reportNo: String?
    let weatherAm: String?
    let weatherPm: String?
    let logDate: String
    let projectName: String
    let contractorName: String
    let approvedDurationDays: Int?
    let accumulatedDays: Int?
    let remainingDays: Int?
    let extendedDays: Int?
    let startDate: String?
    let completionDate: String?
    let plannedProgress: Double?
    let actualProgress: String?
    let specialItemA: String
    let specialItemB: String
    let hasTechnician: Bool
    let preWorkEducation: String
    let newWorkerInsurance: String
    let ppeCheck: String
    let otherSafetyNotes: String
    let sampleTestRecord: String
    let subcontractorNotice: String
    let importantNotes: String
    let siteManagerSigned: Bool
    let workItems: [ConstructionDailyLogWorkItemDTO]
    let materials: [ConstructionDailyLogMaterialRowDTO]
    let personnelEquipmentRows: [ConstructionDailyLogPersonnelRowDTO]
}

struct ConstructionDailyLogDetailEnvelope: Decodable, Sendable {
    let data: ConstructionDailyLogDetailDTO
}

// MARK: - Upsert (POST / PATCH body)

/// 與後端 `constructionDailyLogCreateSchema` 欄位一致（camelCase JSON）。
struct ConstructionDailyLogUpsertBody: Encodable, Sendable {
    var reportNo: String?
    var weatherAm: String?
    var weatherPm: String?
    var logDate: String
    var projectName: String
    var contractorName: String
    var approvedDurationDays: Int?
    var accumulatedDays: Int?
    var remainingDays: Int?
    var extendedDays: Int?
    var startDate: String?
    var completionDate: String?
    var actualProgress: Double?
    var specialItemA: String
    var specialItemB: String
    var hasTechnician: Bool
    var preWorkEducation: String
    var newWorkerInsurance: String
    var ppeCheck: String
    var otherSafetyNotes: String
    var sampleTestRecord: String
    var subcontractorNotice: String
    var importantNotes: String
    var siteManagerSigned: Bool
    var workItems: [ConstructionDailyLogUpsertWorkItem]
    var materials: [ConstructionDailyLogUpsertMaterial]
    var personnelEquipmentRows: [ConstructionDailyLogUpsertPersonnel]
}

struct ConstructionDailyLogUpsertWorkItem: Encodable, Sendable {
    var pccesItemId: String?
    var unitPrice: String?
    var workItemName: String
    var unit: String
    var contractQty: String
    var dailyQty: String
    var accumulatedQty: String
    var remark: String
}

struct ConstructionDailyLogUpsertMaterial: Encodable, Sendable {
    var projectResourceId: String?
    var materialName: String
    var unit: String
    var contractQty: String
    var dailyUsedQty: String
    var accumulatedQty: String
    var remark: String
}

struct ConstructionDailyLogUpsertPersonnel: Encodable, Sendable {
    var projectResourceId: String?
    var workType: String
    var dailyWorkers: Int
    var accumulatedWorkers: Int
    var equipmentName: String
    var dailyEquipmentQty: String
    var accumulatedEquipmentQty: String
}
