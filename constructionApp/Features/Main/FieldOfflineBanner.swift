//
//  FieldOfflineBanner.swift
//  constructionApp
//

import SwiftUI

struct FieldOfflineBanner: View {
    @Environment(FieldNetworkMonitor.self) private var network

    var body: some View {
        Group {
            if !network.isReachable {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TacticalGlassTheme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("離線模式")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text("新增內容將排入待上傳，連線後自動同步。")
                            .font(.caption2)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(TacticalGlassTheme.surfaceContainer.opacity(0.95))
            }
        }
    }
}
