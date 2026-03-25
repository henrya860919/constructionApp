//
//  SelfInspectionAPIModels.swift
//  constructionApp
//
//  Aligns with `project-self-inspection` API responses.
//

import Foundation

// MARK: - List templates (linked to project)

struct SelfInspectionTemplatesEnvelope: Decodable, Sendable {
    let data: [SelfInspectionProjectTemplateDTO]
}

struct SelfInspectionProjectTemplateDTO: Decodable, Identifiable, Sendable {
    let id: String
    let tenantId: String
    let name: String
    let description: String?
    let status: String
    let recordCount: Int
    let linkedAt: String
    let createdAt: String
    let updatedAt: String
}

// MARK: - Template hub (structure for form)

struct SelfInspectionTemplateHubEnvelope: Decodable, Sendable {
    let data: SelfInspectionTemplateHubDTO
}

struct SelfInspectionTemplateHubDTO: Decodable, Sendable {
    let template: SelfInspectionTemplateDetailDTO
    let blocks: [SelfInspectionBlockDTO]
    let recordCount: Int
}

struct SelfInspectionTemplateDetailDTO: Decodable, Sendable {
    let id: String
    let tenantId: String
    let name: String
    let description: String?
    let status: String
    let headerConfig: SelfInspectionHeaderConfigDTO
    let createdAt: String
    let updatedAt: String
}

struct SelfInspectionHeaderConfigDTO: Decodable, Sendable {
    let inspectionNameLabel: String?
    let projectNameLabel: String
    let subProjectLabel: String
    let subcontractorLabel: String
    let inspectionLocationLabel: String
    let inspectionDateLabel: String
    let timingSectionLabel: String
    let timingOptions: [SelfInspectionOptionDTO]
    let resultSectionLabel: String
    let resultLegendOptions: [SelfInspectionOptionDTO]
}

struct SelfInspectionOptionDTO: Decodable, Sendable, Identifiable {
    let id: String
    let label: String
}

struct SelfInspectionBlockDTO: Decodable, Identifiable, Sendable {
    let id: String
    let templateId: String
    let title: String
    let description: String?
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    let items: [SelfInspectionBlockItemDTO]
}

struct SelfInspectionBlockItemDTO: Decodable, Identifiable, Sendable {
    let id: String
    let blockId: String
    let categoryLabel: String
    let itemName: String
    let standardText: String
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
}

// MARK: - Records list

struct SelfInspectionRecordsEnvelope: Decodable, Sendable {
    let data: [SelfInspectionRecordListDTO]
    let meta: PageMetaDTO
}

struct SelfInspectionFilledByDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let email: String?
}

struct SelfInspectionRecordListDTO: Decodable, Identifiable, Sendable {
    let id: String
    let projectId: String
    let templateId: String
    let filledPayload: SelfInspectionFilledPayloadLight?
    let filledById: String?
    let filledBy: SelfInspectionFilledByDTO?
    let createdAt: String
    let updatedAt: String
}

struct SelfInspectionItemFillLight: Decodable, Sendable {
    let resultOptionId: String?
    let actualText: String?
}

/// Decodes `filledPayload`（列表／詳情共用；可含 `items` 供進度統計）
struct SelfInspectionFilledPayloadLight: Decodable, Sendable {
    let header: SelfInspectionHeaderSnapshot?
    let items: [String: SelfInspectionItemFillLight]?
    let photoAttachmentIds: [String]?
}

struct SelfInspectionHeaderSnapshot: Decodable, Sendable {
    let inspectionName: String?
    let projectName: String?
    let subProjectName: String?
    let subcontractor: String?
    let inspectionLocation: String?
    let inspectionDate: String?
    let timingOptionId: String?
}

// MARK: - Structure snapshot（紀錄詳情；與 template hub 同形）

struct SelfInspectionStructureSnapshotDTO: Decodable, Sendable {
    let template: SelfInspectionTemplateDetailDTO
    let blocks: [SelfInspectionBlockDTO]
    let recordCount: Int?
}

extension SelfInspectionStructureSnapshotDTO {
    var asHub: SelfInspectionTemplateHubDTO {
        SelfInspectionTemplateHubDTO(template: template, blocks: blocks, recordCount: recordCount ?? 0)
    }
}

// MARK: - Create / detail / update

struct SelfInspectionCreateRecordEnvelope: Decodable, Sendable {
    let data: SelfInspectionRecordDetailDTO
}

struct SelfInspectionRecordDetailEnvelope: Decodable, Sendable {
    let data: SelfInspectionRecordDetailDTO
}

struct SelfInspectionRecordDetailDTO: Decodable, Identifiable, Sendable {
    let id: String
    let projectId: String
    let templateId: String
    let filledPayload: SelfInspectionFilledPayloadLight?
    let filledById: String?
    let filledBy: SelfInspectionFilledByDTO?
    let createdAt: String
    let updatedAt: String
    let structureSnapshot: SelfInspectionStructureSnapshotDTO?
}

struct SelfInspectionCreateRecordBody: Encodable, Sendable {
    let filledPayload: SelfInspectionFilledPayloadEncodable
}

struct SelfInspectionFilledPayloadEncodable: Encodable, Sendable {
    let header: SelfInspectionHeaderValuesEncodable
    let items: [String: SelfInspectionItemFillEncodable]
    let photoAttachmentIds: [String]?

    enum CodingKeys: String, CodingKey {
        case header, items, photoAttachmentIds
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(header, forKey: .header)
        try c.encode(items, forKey: .items)
        if let photoAttachmentIds, !photoAttachmentIds.isEmpty {
            try c.encode(photoAttachmentIds, forKey: .photoAttachmentIds)
        }
    }
}

struct SelfInspectionHeaderValuesEncodable: Encodable, Sendable {
    let inspectionName: String?
    let projectName: String?
    let subProjectName: String?
    let subcontractor: String?
    let inspectionLocation: String?
    let inspectionDate: String?
    let timingOptionId: String?
}

struct SelfInspectionItemFillEncodable: Encodable, Sendable {
    let resultOptionId: String
}
