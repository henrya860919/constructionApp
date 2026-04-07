//
//  AuthenticatedRemoteImage.swift
//  constructionApp
//

import SwiftUI

/// 以 Bearer token 載入後端 `/api/v1/files/...` 圖片（AsyncImage 不會帶 Authorization）。
struct AuthenticatedRemoteImage: View {
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session
    let apiPath: String
    /// 全螢幕預覽等情境：完整顯示圖片（預設為方格縮放填滿裁切）。
    var scaledToFit: Bool = false

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .modifier(RemoteImageScaleModifier(fit: scaledToFit))
            } else if loadFailed {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: apiPath) {
            await load()
        }
    }

    private func load() async {
        image = nil
        loadFailed = false
        if let cached = FieldCacheStorage.readCachedImageData(forApiPath: apiPath),
           let ui = UIImage(data: cached) {
            await MainActor.run { self.image = ui }
            return
        }
        guard let url = AppConfiguration.absoluteURL(apiPath: apiPath) else {
            await MainActor.run { loadFailed = true }
            return
        }
        do {
            let data = try await session.withValidAccessToken { token in
                try await APIService.fetchAuthorizedData(url: url, token: token)
            }
            if let ui = UIImage(data: data) {
                FieldCacheStorage.writeCachedImageData(data, forApiPath: apiPath)
                await MainActor.run { self.image = ui }
            } else {
                await MainActor.run { loadFailed = true }
            }
        } catch {
            await MainActor.run { loadFailed = true }
        }
    }
}

private struct RemoteImageScaleModifier: ViewModifier {
    var fit: Bool

    func body(content: Content) -> some View {
        if fit {
            content.scaledToFit()
        } else {
            content.scaledToFill()
        }
    }
}
