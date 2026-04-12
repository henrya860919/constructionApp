//
//  FieldDailyLogMaterialReconcile.swift
//  constructionApp
//
//  對齊網頁 `mergeSavedMaterialsWithResourceMetadata` / `recalcMaterialAccumulatedFromPriors`。
//

import Foundation

enum FieldDailyLogMaterialReconcile {
    static func mergeSaved(
        resources: [ConstructionDailyLogMaterialResourceDTO],
        saved: [FieldDailyLogMaterialRow],
        priors: [String: String]
    ) -> [FieldDailyLogMaterialRow] {
        var resById: [String: ConstructionDailyLogMaterialResourceDTO] = [:]
        for r in resources { resById[r.id] = r }
        var out: [FieldDailyLogMaterialRow] = []
        for s in saved {
            if let rid = s.projectResourceId, !rid.isEmpty {
                let r = resById[rid]
                let prior = FieldDailyLogPersonnelReconcile.parseDecimalString(priors[rid] ?? "0")
                let dailyS = s.dailyUsedQty
                let daily = FieldDailyLogPersonnelReconcile.parseDecimalString(dailyS)
                let nameTrim = s.materialName.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = nameTrim.isEmpty ? (r?.name ?? "") : nameTrim
                let unitTrim = s.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedUnit = unitTrim.isEmpty ? (r?.unit ?? "") : unitTrim
                let accTrim = s.accumulatedQty.trimmingCharacters(in: .whitespacesAndNewlines)
                let accumulated = accTrim.isEmpty
                    ? FieldDailyLogPersonnelReconcile.formatDecimal(prior + daily)
                    : s.accumulatedQty
                out.append(
                    FieldDailyLogMaterialRow(
                        id: s.id,
                        projectResourceId: rid,
                        materialName: resolvedName,
                        unit: resolvedUnit,
                        contractQty: "0",
                        dailyUsedQty: dailyS,
                        accumulatedQty: accumulated,
                        remark: s.remark
                    )
                )
            } else {
                out.append(s)
            }
        }
        return out
    }

    static func recalcAccumulatedFromPriors(
        _ rows: inout [FieldDailyLogMaterialRow],
        priors: [String: String]
    ) {
        for i in rows.indices {
            guard let rid = rows[i].projectResourceId, !rid.isEmpty else { continue }
            let prior = FieldDailyLogPersonnelReconcile.parseDecimalString(priors[rid] ?? "0")
            let daily = FieldDailyLogPersonnelReconcile.parseDecimalString(rows[i].dailyUsedQty)
            rows[i].accumulatedQty = FieldDailyLogPersonnelReconcile.formatDecimal(prior + daily)
        }
    }
}
