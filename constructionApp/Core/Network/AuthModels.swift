//
//  AuthModels.swift
//  constructionApp
//

import Foundation

struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let name: String
    let hasAvatar: Bool
    let systemRole: String
    let tenantId: String?
}

struct LoginResponse: Decodable, Sendable {
    struct DataPart: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String?
        let user: AuthUser
    }

    let data: DataPart
}

struct LoginResult: Sendable {
    let accessToken: String
    let refreshToken: String?
    let user: AuthUser
}

struct RefreshTokenEnvelope: Decodable, Sendable {
    struct DataPart: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
    }

    let data: DataPart
}

struct AppVersionDTO: Decodable, Sendable {
    let minimumVersion: String
    let latestVersion: String
    let appStoreURL: String
}

struct AppVersionEnvelope: Decodable, Sendable {
    let data: AppVersionDTO
}

struct MeResponse: Decodable, Sendable {
    let data: AuthUser
}

struct ProjectSummary: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let code: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, name, code, status
    }
}

struct ProjectListResponse: Decodable, Sendable {
    let data: [ProjectSummary]
    let meta: Meta?

    struct Meta: Decodable, Sendable {
        let page: Int
        let limit: Int
        let total: Int
    }
}
