//
//  FieldCacheStorageDetailView.swift
//  constructionApp
//

import SwiftUI

struct FieldCacheStorageDetailView: View {
    @State private var breakdown = FieldCacheStorage.usageBreakdown()
    @State private var showClearConfirm = false
    @State private var isClearing = false

    private var budget: Int64 { FieldCacheStorage.displayBudgetBytes }

    private var usageRatio: CGFloat {
        guard budget > 0 else { return 0 }
        return min(1, CGFloat(Double(breakdown.totalBytes) / Double(budget)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("用量")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .tracking(0.8)

                        Text(
                            "\(FieldByteCountFormatter.megabytesString(breakdown.totalBytes))"
                                + " / \(FieldByteCountFormatter.megabytesString(budget))"
                        )
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .fill(TacticalGlassTheme.surfaceContainerHighest.opacity(0.5))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .fill(TacticalGlassTheme.primaryGradient())
                                    .frame(width: max(0, geo.size.width * usageRatio), height: 8)
                            }
                        }
                        .frame(height: 8)

                        breakdownRows
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("說明")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .tracking(0.8)

                        Text("暫存包含下載圖片與網路回應快取，可隨時清除；清除後列表與預覽圖會重新下載。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("尚未上傳至伺服器的紀錄與照片不會被清除。")
                            .font(.subheadline)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    showClearConfirm = true
                } label: {
                    if isClearing {
                        ProgressView()
                            .tint(TacticalGlassTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    } else {
                        Text("清除暫存")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                }
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .fill(TacticalGlassTheme.surfaceContainer)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
                .disabled(isClearing)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
        .navigationTitle("暫存空間")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            reloadBreakdown()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldCacheStorageDidChange)) { _ in
            reloadBreakdown()
        }
        .alert("要清除暫存嗎？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await performClear() }
            }
        } message: {
            Text("將刪除可重建的快取，不影響尚未上傳的資料。清除後圖片會在檢視時重新下載。")
        }
    }

    private var breakdownRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            usageLine(
                title: "網路快取",
                bytes: breakdown.networkBytes
            )
            usageLine(
                title: "圖片暫存",
                bytes: breakdown.imageBytes
            )
        }
        .padding(.top, 4)
    }

    private func usageLine(title: String, bytes: Int64) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(0.5)
            Spacer(minLength: 8)
            Text(FieldByteCountFormatter.megabytesString(bytes))
                .font(.tacticalMonoFixed(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func reloadBreakdown() {
        breakdown = FieldCacheStorage.usageBreakdown()
    }

    @MainActor
    private func performClear() async {
        isClearing = true
        defer { isClearing = false }
        FieldCacheStorage.clearAllCaches()
        reloadBreakdown()
    }
}

// MARK: - 設定列表列（摘要）

struct FieldCacheStorageSettingsRow: View {
    @State private var breakdown = FieldCacheStorage.usageBreakdown()

    private var budget: Int64 { FieldCacheStorage.displayBudgetBytes }

    var body: some View {
        NavigationLink {
            FieldCacheStorageDetailView()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("暫存空間")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(
                        "\(FieldByteCountFormatter.megabytesString(breakdown.totalBytes))"
                            + " / \(FieldByteCountFormatter.megabytesString(budget))"
                    )
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    Text("圖片與網路快取 · 點進管理")
                        .font(.caption2)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.9))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            breakdown = FieldCacheStorage.usageBreakdown()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldCacheStorageDidChange)) { _ in
            breakdown = FieldCacheStorage.usageBreakdown()
        }
    }
}

#Preview("Detail") {
    NavigationStack {
        FieldCacheStorageDetailView()
    }
}
