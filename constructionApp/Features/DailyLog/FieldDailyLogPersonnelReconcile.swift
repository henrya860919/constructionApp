//
//  FieldDailyLogPersonnelReconcile.swift
//  constructionApp
//
//  對齊網頁 `daily-log-form-helpers`：reconcile + 累計重算。
//

import Foundation

enum FieldDailyLogPersonnelReconcile {
    static func parseIntString(_ s: String) -> Int {
        Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    static func parseDecimalString(_ s: String) -> Double {
        let t = s.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(t) ?? 0
    }

    static func formatDecimal(_ x: Double) -> String {
        if x.isNaN || x.isInfinite { return "0" }
        let rounded = (x * 1_000_000).rounded() / 1_000_000
        if abs(rounded - rounded.rounded()) < 1e-9 {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    /// 資源庫列 + 已存草稿 + 填表日前合計 → 表單列（人力在前，與後端排序一致）。
    static func reconcile(
        resources: [ConstructionDailyLogPersonnelResourceDTO],
        saved: [FieldDailyLogPersonnelEquipmentRow],
        priors: [String: String]
    ) -> [FieldDailyLogPersonnelEquipmentRow] {
        var savedByRid: [String: FieldDailyLogPersonnelEquipmentRow] = [:]
        var manual: [FieldDailyLogPersonnelEquipmentRow] = []
        for row in saved {
            if let rid = row.projectResourceId, !rid.isEmpty {
                savedByRid[rid] = row
            } else {
                manual.append(row)
            }
        }
        var out: [FieldDailyLogPersonnelEquipmentRow] = []
        for r in resources {
            let prior = priors[r.id] ?? "0"
            let s = savedByRid[r.id]
            if r.type == "labor" {
                let priorN = parseIntString(prior)
                let dailyStr = s?.dailyWorkers ?? "0"
                let daily = parseIntString(dailyStr)
                out.append(
                    FieldDailyLogPersonnelEquipmentRow(
                        id: s?.id ?? "r:\(r.id)",
                        projectResourceId: r.id,
                        resourceType: "labor",
                        unit: r.unit,
                        workType: s?.workType ?? r.name,
                        dailyWorkers: dailyStr,
                        accumulatedWorkers: String(priorN + daily),
                        equipmentName: "",
                        dailyEquipmentQty: "0",
                        accumulatedEquipmentQty: "0"
                    )
                )
            } else {
                let priorD = parseDecimalString(prior)
                let dailyStr = s?.dailyEquipmentQty ?? "0"
                let daily = parseDecimalString(dailyStr)
                out.append(
                    FieldDailyLogPersonnelEquipmentRow(
                        id: s?.id ?? "r:\(r.id)",
                        projectResourceId: r.id,
                        resourceType: "equipment",
                        unit: r.unit,
                        workType: "",
                        dailyWorkers: "0",
                        accumulatedWorkers: "0",
                        equipmentName: s?.equipmentName ?? r.name,
                        dailyEquipmentQty: dailyStr,
                        accumulatedEquipmentQty: formatDecimal(priorD + daily)
                    )
                )
            }
        }
        out.append(contentsOf: manual)
        return out
    }
}
