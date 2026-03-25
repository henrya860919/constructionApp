//
//  ModuleHomeViews.swift
//  constructionApp
//

import SwiftUI

struct SelfInspectionHomeView: View {
    var body: some View {
        SelfInspectionModuleView()
    }
}

struct DailyLogHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                obsidianModuleHeader(title: "施工日誌")
                Text("公共工程施工日誌（依附表四）")
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)

                endpointCard(
                    path: "projects/{projectId}/construction-daily-logs",
                    note: "與儀表板施工日誌／PCCES 流程同一資料來源"
                )
            }
            .padding(24)
        }
        .contentMargins(.bottom, TacticalGlassTheme.tabBarScrollBottomMargin, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
    }
}

// MARK: - Shared

private func endpointCard(path: String, note: String) -> some View {
    TacticalGlassCard {
        VStack(alignment: .leading, spacing: 14) {
            Text("ENDPOINT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.primary)
                .tracking(1)

            Text("/api/v1/" + path)
                .font(.tacticalMonoFixed(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)

            Text(note)
                .font(.footnote)
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
        }
    }
}
