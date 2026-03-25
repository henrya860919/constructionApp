//
//  DrawingAPIModels.swift
//  constructionApp
//

import Foundation

struct DrawingNodeDTO: Decodable, Sendable, Identifiable {
    let id: String
    let kind: String
    let name: String
    let latestFile: DrawingLatestFileDTO?
    let children: [DrawingNodeDTO]?

    var isFolder: Bool { kind == "folder" }
    var isLeaf: Bool { kind == "leaf" }
}

struct DrawingLatestFileDTO: Decodable, Sendable {
    let id: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let createdAt: String
}

struct DrawingUploaderDTO: Decodable, Sendable {
    let id: String
    let name: String
    let email: String?
}

struct DrawingRevisionDTO: Decodable, Sendable, Identifiable {
    let id: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let createdAt: String
    let uploadedBy: DrawingUploaderDTO?
    let url: String
}

struct DrawingNodeTreeEnvelope: Decodable, Sendable {
    let data: [DrawingNodeDTO]
}

struct DrawingRevisionsEnvelope: Decodable, Sendable {
    let data: [DrawingRevisionDTO]
}
