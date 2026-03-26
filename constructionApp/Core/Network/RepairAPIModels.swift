//
//  RepairAPIModels.swift
//  constructionApp
//
//  對齊後端 repair-request controller `toRepairDto` / `toRepairRecordDto`。
//

import Foundation

struct PageMetaDTO: Codable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
}

struct RepairListEnvelope: Decodable, Sendable {
    let data: [RepairListItemDTO]
    let meta: PageMetaDTO
}

struct RepairListItemDTO: Codable, Identifiable, Sendable {
    let id: String
    let projectId: String
    let customerName: String
    let contactPhone: String
    let repairContent: String
    let unitLabel: String?
    let remarks: String?
    let problemCategory: String
    let isSecondRepair: Bool
    let deliveryDate: String?
    let repairDate: String?
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct RepairDetailEnvelope: Decodable, Sendable {
    let data: RepairDetailDTO
}

struct RepairDetailDTO: Decodable, Sendable {
    let id: String
    let projectId: String
    let customerName: String
    let contactPhone: String
    let repairContent: String
    let unitLabel: String?
    let remarks: String?
    let problemCategory: String
    let isSecondRepair: Bool
    let deliveryDate: String?
    let repairDate: String?
    let status: String
    let createdAt: String
    let updatedAt: String
    let photos: [FileAttachmentDTO]?
    let attachments: [FileAttachmentDTO]?
}

struct FileAttachmentDTO: Decodable, Identifiable, Sendable {
    let id: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let createdAt: String
    let url: String
}

struct RepairRecordsEnvelope: Decodable, Sendable {
    let data: [RepairExecutionRecordDTO]
}

struct RepairExecutionRecordDTO: Decodable, Identifiable, Sendable {
    let id: String
    let repairId: String
    let content: String
    let recordedById: String?
    let recordedBy: RecordedByUserDTO?
    let createdAt: String
    let photos: [FileAttachmentDTO]?
}

struct RecordedByUserDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let email: String
}

// MARK: - Create / Upload

struct RepairItemEnvelope: Decodable, Sendable {
    let data: RepairListItemDTO
}

struct RepairExecutionRecordItemEnvelope: Decodable, Sendable {
    let data: RepairExecutionRecordDTO
}

/// `PATCH …/repair-requests/:id` — 與後端 `updateRepairRequestSchema` 對齊（每次儲存送完整欄位）。
struct UpdateRepairRequestBody: Encodable, Sendable {
    let customerName: String
    let contactPhone: String
    let repairContent: String
    let problemCategory: String
    let isSecondRepair: Bool
    let status: String
    let unitLabel: String?
    let remarks: String?
    let deliveryDate: String?
    let repairDate: String?
    let photoAttachmentIds: [String]
    let fileAttachmentIds: [String]
}

/// `POST …/repair-requests/:id/records`
struct CreateRepairExecutionRecordBody: Encodable, Sendable {
    let content: String
    let attachmentIds: [String]
}

/// `PATCH …/repair-requests/:id/records/:recordId`
struct UpdateRepairExecutionRecordBody: Encodable, Sendable {
    let content: String
    let attachmentIds: [String]
}

struct FileUploadEnvelope: Decodable, Sendable {
    struct DataPart: Decodable, Sendable {
        let id: String
        let fileName: String
        let fileSize: Int
        let mimeType: String
    }

    let data: DataPart
}

/// JSON body for `POST …/repair-requests`（與後端 `createRepairRequestSchema` 一致）。
struct CreateRepairRequestBody: Encodable, Sendable {
    let customerName: String
    let contactPhone: String
    let repairContent: String
    let problemCategory: String
    let isSecondRepair: Bool
    let status: String
    let unitLabel: String?
    let remarks: String?
    let deliveryDate: String?
    let repairDate: String?
    let photoAttachmentIds: [String]?
    let fileAttachmentIds: [String]?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(customerName, forKey: .customerName)
        try c.encode(contactPhone, forKey: .contactPhone)
        try c.encode(repairContent, forKey: .repairContent)
        try c.encode(problemCategory, forKey: .problemCategory)
        try c.encode(isSecondRepair, forKey: .isSecondRepair)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(unitLabel, forKey: .unitLabel)
        try c.encodeIfPresent(remarks, forKey: .remarks)
        try c.encodeIfPresent(deliveryDate, forKey: .deliveryDate)
        try c.encodeIfPresent(repairDate, forKey: .repairDate)
        try c.encodeIfPresent(photoAttachmentIds, forKey: .photoAttachmentIds)
        try c.encodeIfPresent(fileAttachmentIds, forKey: .fileAttachmentIds)
    }

    private enum CodingKeys: String, CodingKey {
        case customerName, contactPhone, repairContent, problemCategory, isSecondRepair, status
        case unitLabel, remarks, deliveryDate, repairDate, photoAttachmentIds, fileAttachmentIds
    }
}
