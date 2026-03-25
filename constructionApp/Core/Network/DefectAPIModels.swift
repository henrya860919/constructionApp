//
//  DefectAPIModels.swift
//  constructionApp
//
//  Aligns with backend `defect-improvement.controller.ts` `toDefectDto` / `toRecordDto`.
//

import Foundation

struct DefectListEnvelope: Decodable, Sendable {
    let data: [DefectListItemDTO]
    let meta: PageMetaDTO
}

struct DefectListItemDTO: Decodable, Identifiable, Sendable {
    let id: String
    let projectId: String
    let description: String
    let discoveredBy: String
    let priority: String
    let floor: String?
    let location: String?
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct DefectDetailEnvelope: Decodable, Sendable {
    let data: DefectDetailDTO
}

struct DefectDetailDTO: Decodable, Sendable {
    let id: String
    let projectId: String
    let description: String
    let discoveredBy: String
    let priority: String
    let floor: String?
    let location: String?
    let status: String
    let createdAt: String
    let updatedAt: String
    let photos: [FileAttachmentDTO]?
}

struct DefectRecordsEnvelope: Decodable, Sendable {
    let data: [DefectExecutionRecordDTO]
}

struct DefectExecutionRecordDTO: Decodable, Identifiable, Sendable {
    let id: String
    let defectId: String
    let content: String
    let recordedById: String?
    let recordedBy: RecordedByUserDTO?
    let createdAt: String
    let photos: [FileAttachmentDTO]?
}

struct DefectItemEnvelope: Decodable, Sendable {
    let data: DefectListItemDTO
}

/// `POST …/defect-improvements` — matches `createDefectImprovementSchema`.
struct CreateDefectImprovementBody: Encodable, Sendable {
    let description: String
    let discoveredBy: String
    let priority: String
    let floor: String?
    let location: String?
    let status: String
    let attachmentIds: [String]
}

/// `POST …/defect-improvements/:id/records` — matches `createDefectExecutionRecordSchema`.
struct CreateDefectExecutionRecordBody: Encodable, Sendable {
    let content: String
    let attachmentIds: [String]
}

struct DefectExecutionRecordItemEnvelope: Decodable, Sendable {
    let data: DefectExecutionRecordDTO
}

/// `PATCH …/defect-improvements/:id`
struct UpdateDefectImprovementBody: Encodable, Sendable {
    let description: String
    let discoveredBy: String
    let priority: String
    let floor: String?
    let location: String?
    let status: String
    let attachmentIds: [String]
}

/// `PATCH …/defect-improvements/:id/records/:recordId`
struct UpdateDefectExecutionRecordBody: Encodable, Sendable {
    let content: String
    let attachmentIds: [String]
}
