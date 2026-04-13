//
//  ConstructionDailyLogFormDefaultsDTO.swift
//  constructionApp
//
//  對齊網頁 `getConstructionDailyLogDefaults`（專案主檔、人機材料資源與 priors）。
//

import Foundation

struct ConstructionDailyLogProgressPlanKnotDTO: Decodable, Sendable, Hashable {
    let periodDate: String
    let cumulativePlanned: String
}

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
    let projectName: String
    let contractorName: String
    let startDate: String?
    let approvedDurationDays: Int?
    let progressPlanKnots: [ConstructionDailyLogProgressPlanKnotDTO]
    let personnelResources: [ConstructionDailyLogPersonnelResourceDTO]
    let personnelResourcePriors: [String: String]
    let materialResources: [ConstructionDailyLogMaterialResourceDTO]
    let materialResourcePriors: [String: String]

    enum CodingKeys: String, CodingKey {
        case projectName
        case contractorName
        case startDate
        case approvedDurationDays
        case progressPlanKnots
        case personnelResources
        case personnelResourcePriors
        case materialResources
        case materialResourcePriors
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? ""
        contractorName = try c.decodeIfPresent(String.self, forKey: .contractorName) ?? ""
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        approvedDurationDays = try c.decodeIfPresent(Int.self, forKey: .approvedDurationDays)
        progressPlanKnots = try c.decodeIfPresent([ConstructionDailyLogProgressPlanKnotDTO].self, forKey: .progressPlanKnots) ?? []
        personnelResources = try c.decodeIfPresent([ConstructionDailyLogPersonnelResourceDTO].self, forKey: .personnelResources) ?? []
        personnelResourcePriors = try c.decodeIfPresent([String: String].self, forKey: .personnelResourcePriors) ?? [:]
        materialResources = try c.decodeIfPresent([ConstructionDailyLogMaterialResourceDTO].self, forKey: .materialResources) ?? []
        materialResourcePriors = try c.decodeIfPresent([String: String].self, forKey: .materialResourcePriors) ?? [:]
    }
}

struct ConstructionDailyLogFormDefaultsEnvelope: Decodable, Sendable {
    let data: ConstructionDailyLogFormDefaultsDTO
}
