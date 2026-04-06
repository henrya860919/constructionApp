//
//  FieldDailyLogLocalStore.swift
//  constructionApp
//
//  施工日誌草稿：依專案存在 UserDefaults（之後可改接 API）。
//

import Foundation
import Observation

struct FieldDailyLogPersistedDay: Codable, Equatable {
    var weatherRaw: String?
    var notes: String

    static let empty = FieldDailyLogPersistedDay(weatherRaw: nil, notes: "")
}

@MainActor
@Observable
final class FieldDailyLogLocalStore {
    private let defaults: UserDefaults
    private var byDay: [String: FieldDailyLogPersistedDay] = [:]
    /// 最後一次成功寫入磁碟的快照（用於判斷是否有未儲存變更）
    private var lastWritten: [String: FieldDailyLogPersistedDay] = [:]
    private(set) var projectId: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activateProject(_ id: String) {
        guard projectId != id else { return }
        projectId = id
        byDay = Self.readMap(defaults: defaults, projectId: id)
        lastWritten = byDay
    }

    func day(for key: String) -> FieldDailyLogPersistedDay {
        byDay[key] ?? .empty
    }

    func setDay(_ key: String, value: FieldDailyLogPersistedDay) {
        byDay[key] = value
    }

    func isDirty(dayKey: String) -> Bool {
        let cur = byDay[dayKey] ?? .empty
        let saved = lastWritten[dayKey] ?? .empty
        return cur != saved
    }

    func save(dayKey: String) {
        guard let pid = projectId else { return }
        lastWritten[dayKey] = byDay[dayKey] ?? .empty
        Self.writeMap(defaults: defaults, projectId: pid, map: byDay)
    }

    private static func storageKey(projectId: String) -> String {
        "field.constructionDailyLog.v1.\(projectId)"
    }

    private static func readMap(defaults: UserDefaults, projectId: String) -> [String: FieldDailyLogPersistedDay] {
        let key = storageKey(projectId: projectId)
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: FieldDailyLogPersistedDay].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func writeMap(defaults: UserDefaults, projectId: String, map: [String: FieldDailyLogPersistedDay]) {
        let key = storageKey(projectId: projectId)
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: key)
    }
}
