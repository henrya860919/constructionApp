//
//  ConstructionDailyLogPccesAPIModels.swift
//  constructionApp
//
//  GET /api/v1/projects/:projectId/construction-daily-logs/pcces-work-items
//  與前端 `ConstructionDailyLogPccesPickerResponse` 對齊。
//

import Foundation

struct ConstructionDailyLogPccesPickerImportDTO: Decodable, Sendable {
    let id: String
    let version: Int
    let approvedAt: String?
    let approvedById: String?
    let approvalEffectiveAt: String?
}

struct ConstructionDailyLogPccesPickerRowDTO: Decodable, Sendable, Identifiable, Hashable {
    let pccesItemId: String
    let itemKey: Int
    let parentItemKey: Int?
    let itemNo: String
    let workItemName: String
    let unit: String
    let itemKind: String
    let contractQty: String
    let unitPrice: String
    let isStructuralLeaf: Bool
    let priorAccumulatedQty: String?

    var id: String { pccesItemId }

    /// 與後端一致：有子列者為目錄（不可選）；`isStructuralLeaf` 為 true 才可勾選。
    var isSelectableLeaf: Bool { isStructuralLeaf }
}

struct ConstructionDailyLogPccesPickerResponseDTO: Decodable, Sendable {
    let pccesImport: ConstructionDailyLogPccesPickerImportDTO?
    let rows: [ConstructionDailyLogPccesPickerRowDTO]
}

struct ConstructionDailyLogPccesPickerEnvelope: Decodable, Sendable {
    let data: ConstructionDailyLogPccesPickerResponseDTO
}
