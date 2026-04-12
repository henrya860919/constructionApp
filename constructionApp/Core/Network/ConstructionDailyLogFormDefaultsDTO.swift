//
//  ConstructionDailyLogFormDefaultsDTO.swift
//  constructionApp
//
//  對齊網頁 `getConstructionDailyLogDefaults`（僅解 personnel 相關欄位即可）。
//

import Foundation

struct ConstructionDailyLogPersonnelResourceDTO: Decodable, Sendable, Hashable {
    let id: String
    let type: String
    let name: String
    let unit: String
}

struct ConstructionDailyLogMaterialResourceDTO: Decodable, Sendable, Hashable {
    let id: String
    let name: String
    let unit: String
}

struct ConstructionDailyLogFormDefaultsDTO: Decodable, Sendable {
    let personnelResources: [ConstructionDailyLogPersonnelResourceDTO]
    let personnelResourcePriors: [String: String]
    let materialResources: [ConstructionDailyLogMaterialResourceDTO]
    let materialResourcePriors: [String: String]

    enum CodingKeys: String, CodingKey {
        case personnelResources
        case personnelResourcePriors
        case materialResources
        case materialResourcePriors
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        personnelResources = try c.decodeIfPresent([ConstructionDailyLogPersonnelResourceDTO].self, forKey: .personnelResources) ?? []
        personnelResourcePriors = try c.decodeIfPresent([String: String].self, forKey: .personnelResourcePriors) ?? [:]
        materialResources = try c.decodeIfPresent([ConstructionDailyLogMaterialResourceDTO].self, forKey: .materialResources) ?? []
        materialResourcePriors = try c.decodeIfPresent([String: String].self, forKey: .materialResourcePriors) ?? [:]
    }
}

struct ConstructionDailyLogFormDefaultsEnvelope: Decodable, Sendable {
    let data: ConstructionDailyLogFormDefaultsDTO
}
