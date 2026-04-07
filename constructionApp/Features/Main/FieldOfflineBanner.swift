//
//  FieldOfflineBanner.swift
//  constructionApp
//

import SwiftUI

struct FieldOfflineBanner: View {
    @Environment(\.fieldTheme) private var theme
    @Environment(FieldNetworkMonitor.self) private var network

    var body: some View {
        Group {
            if !network.isReachable {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.primary)
                    Text("離線模式 · 新增將排入待上傳，連線後自動同步")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.mutedLabel)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    theme.surfaceContainer.opacity(0.96)
                        .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                }
            }
        }
    }
}
