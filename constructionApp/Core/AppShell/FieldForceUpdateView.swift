//
//  FieldForceUpdateView.swift
//  constructionApp
//

import SwiftUI

/// 版號低於後端 `minimumVersion` 時全螢幕阻擋，引導前往 App Store。
struct FieldForceUpdateView: View {
    var appStoreURL: URL?

    var body: some View {
        ZStack {
            TacticalGlassTheme.surface
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(TacticalGlassTheme.primary)
                Text("請更新 App")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("目前版本已無法使用，請至 App Store 更新至最新版後再開啟。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                if let url = appStoreURL {
                    Link(destination: url) {
                        Text("前往 App Store")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(TacticalPrimaryButtonStyle())
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                }
            }
        }
    }
}
