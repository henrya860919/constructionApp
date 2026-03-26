//
//  FieldCenteredRecordLoadErrorView.swift
//  constructionApp
//
//  紀錄詳情載入失敗時置中說明（離線／連線與一般錯誤）。
//

import SwiftUI

struct FieldCenteredRecordLoadErrorView: View {
    /// 是否為離線、無網路等連線問題（不顯示系統英文細節為主訊息）。
    var isConnectivityOrOffline: Bool
    /// 非連線類錯誤時可顯示後端／系統訊息；連線類通常傳 `nil` 避免整段英文。
    var localizedErrorDetail: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: isConnectivityOrOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(isConnectivityOrOffline ? TacticalGlassTheme.primary : TacticalGlassTheme.tertiary)
            Text(isConnectivityOrOffline ? "目前無法載入此筆紀錄" : "無法載入此筆紀錄")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(
                isConnectivityOrOffline
                    ? "裝置正處於離線狀態或無法連上伺服器，完整內容需網路連線後才能顯示。"
                    : "載入時發生錯誤。請稍後再試，或確認網路與登入狀態。"
            )
            .font(.subheadline)
            .foregroundStyle(TacticalGlassTheme.mutedLabel)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            if let localizedErrorDetail, !localizedErrorDetail.isEmpty {
                Text(localizedErrorDetail)
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("連線恢復後，請下拉此頁重新整理。")
                .font(.caption.weight(.medium))
                .foregroundStyle(TacticalGlassTheme.primary.opacity(0.95))
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}
