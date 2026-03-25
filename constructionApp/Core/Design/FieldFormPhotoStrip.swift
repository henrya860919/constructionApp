//
//  FieldFormPhotoStrip.swift
//  constructionApp
//
//  表單內橫向照片列：遠端縮圖 + 本機預覽，風格對齊編輯報修／缺失。
//

import SwiftUI
import UIKit

enum FieldFormPhotoStripMetrics {
    static let thumbLength: CGFloat = 96
}

/// 橫向捲動；先顯示已上傳（遠端）id，再顯示相簿預覽（本機）。
struct FieldFormPhotoStrip: View {
    let accessToken: String
    let remotePhotoIds: [String]
    let localPreviewImages: [UIImage]
    let onRemoveRemote: (String) -> Void
    let onRemoveLocal: (Int) -> Void

    var body: some View {
        if !remotePhotoIds.isEmpty || !localPreviewImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(remotePhotoIds, id: \.self) { id in
                        stripThumb {
                            AuthenticatedRemoteImage(apiPath: "/api/v1/files/\(id)", accessToken: accessToken)
                        } onRemove: {
                            onRemoveRemote(id)
                        }
                    }
                    ForEach(Array(localPreviewImages.indices), id: \.self) { index in
                        stripThumb {
                            Image(uiImage: localPreviewImages[index])
                                .resizable()
                                .scaledToFill()
                        } onRemove: {
                            onRemoveLocal(index)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func stripThumb<Content: View>(
        @ViewBuilder content: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: FieldFormPhotoStripMetrics.thumbLength, height: FieldFormPhotoStripMetrics.thumbLength)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .padding(4)
            .accessibilityLabel("移除照片")
        }
    }
}
