//
//  FieldQuickLookPreview.swift
//  constructionApp
//

import QuickLook
import SwiftUI

private final class FieldQLPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL, title: String?) {
        previewItemURL = url
        previewItemTitle = title
    }
}

private struct FieldQuickLookRepresentable: UIViewControllerRepresentable {
    let fileURL: URL
    let title: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL, title: title)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.fileURL = fileURL
        context.coordinator.titleText = title
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURL: URL
        var titleText: String?

        init(fileURL: URL, title: String?) {
            self.fileURL = fileURL
            titleText = title
        }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }

        func previewController(_: QLPreviewController, previewItemAt _: Int) -> QLPreviewItem {
            FieldQLPreviewItem(url: fileURL, title: titleText)
        }
    }
}

/// 全螢幕 Quick Look，頂部「完成」關閉。
struct FieldQuickLookPreviewSheet: View {
    @Environment(\.fieldTheme) private var theme
    let fileURL: URL
    var title: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FieldQuickLookRepresentable(fileURL: fileURL, title: title)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(theme.surfaceContainerHighest.opacity(0.92))
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
            .accessibilityLabel("關閉預覽")
        }
        .background(theme.surface)
    }
}
