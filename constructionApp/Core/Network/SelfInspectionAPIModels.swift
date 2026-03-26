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

struct SelfInspectionProjectTemplateDTO: Codable, Identifiable, Sendable {
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

struct SelfInspectionTemplateHubDTO: Codable, Sendable {
    let template: SelfInspectionTemplateDetailDTO
    let blocks: [SelfInspectionBlockDTO]
    let recordCount: Int
}

struct SelfInspectionTemplateDetailDTO: Codable, Sendable {
    let id: String
    let tenantId: String
    let name: String
    let description: String?
    let status: String
    let headerConfig: SelfInspectionHeaderConfigDTO
    let createdAt: String
    let updatedAt: String
}

struct SelfInspectionHeaderConfigDTO: Codable, Sendable {
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

struct SelfInspectionOptionDTO: Codable, Sendable, Identifiable {
    let id: String
    let label: String
}

struct SelfInspectionBlockDTO: Codable, Identifiable, Sendable {
    let id: String
    let templateId: String
    let title: String
    let description: String?
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    let items: [SelfInspectionBlockItemDTO]
}

struct SelfInspectionBlockItemDTO: Codable, Identifiable, Sendable {
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

struct SelfInspectionFilledByDTO: Codable, Sendable {
    let id: String
    let name: String?
    let email: String?
}

struct SelfInspectionRecordListDTO: Codable, Identifiable, Sendable {
    let id: String
    let projectId: String
    let templateId: String
    let filledPayload: SelfInspectionFilledPayloadLight?
    let filledById: String?
    let filledBy: SelfInspectionFilledByDTO?
    let createdAt: String
    let updatedAt: String
}

struct SelfInspectionItemFillLight: Codable, Sendable {
    let resultOptionId: String?
    let actualText: String?
}

/// Decodes `filledPayload`（列表／詳情共用；可含 `items` 供進度統計）
struct SelfInspectionFilledPayloadLight: Codable, Sendable {
    let header: SelfInspectionHeaderSnapshot?
    let items: [String: SelfInspectionItemFillLight]?
    let photoAttachmentIds: [String]?
}

struct SelfInspectionHeaderSnapshot: Codable, Sendable {
    let inspectionName: String?
    let projectName: String?
    let subProjectName: String?
    let subcontractor: String?
    let inspectionLocation: String?
    let inspectionDate: String?
    let timingOptionId: String?
}

// MARK: - Structure snapshot（紀錄詳情；與 template hub 同形）

struct SelfInspectionStructureSnapshotDTO: Codable, Sendable {
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

struct SelfInspectionRecordDetailDTO: Codable, Identifiable, Sendable {
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

struct SelfInspectionCreateRecordBody: Codable, Sendable {
    let filledPayload: SelfInspectionFilledPayloadEncodable
}

struct SelfInspectionFilledPayloadEncodable: Codable, Sendable {
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        header = try c.decode(SelfInspectionHeaderValuesEncodable.self, forKey: .header)
        items = try c.decode([String: SelfInspectionItemFillEncodable].self, forKey: .items)
        photoAttachmentIds = try c.decodeIfPresent([String].self, forKey: .photoAttachmentIds)
    }

    init(header: SelfInspectionHeaderValuesEncodable, items: [String: SelfInspectionItemFillEncodable], photoAttachmentIds: [String]?) {
        self.header = header
        self.items = items
        self.photoAttachmentIds = photoAttachmentIds
    }
}

struct SelfInspectionHeaderValuesEncodable: Codable, Sendable {
    let inspectionName: String?
    let projectName: String?
    let subProjectName: String?
    let subcontractor: String?
    let inspectionLocation: String?
    let inspectionDate: String?
    let timingOptionId: String?
}

struct SelfInspectionItemFillEncodable: Codable, Sendable {
    let resultOptionId: String
}
