//
//  FieldCacheStorageDetailView.swift
//  constructionApp
//

import SwiftUI

struct FieldCacheStorageDetailView: View {
    @State private var breakdown = FieldCacheStorage.usageBreakdown()
    @State private var showClearManagedConfirm = false
    @State private var showClearOfflineConfirm = false
    @State private var isClearingManaged = false
    @State private var isClearingOffline = false

    private var managedBudget: Int64 { FieldCacheStorage.displayBudgetBytes }
    private var offlineBudget: Int64 { FieldOfflineDrawingStore.vaultBudgetBytes() }

    private var managedUsageRatio: CGFloat {
        guard managedBudget > 0 else { return 0 }
        return min(1, CGFloat(Double(breakdown.managedCacheBytes) / Double(managedBudget)))
    }

    private var offlineUsageRatio: CGFloat {
        guard offlineBudget > 0 else { return 0 }
        return min(1, CGFloat(Double(breakdown.offlineDrawingBytes) / Double(offlineBudget)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("一般暫存（列表圖、網路）")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(0.8)

                            Text(
                                "\(FieldByteCountFormatter.megabytesString(breakdown.managedCacheBytes))"
                                    + " / \(FieldByteCountFormatter.megabytesString(managedBudget))"
                            )
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                            usageBar(ratio: managedUsageRatio)

                            managedBreakdownRows
                        }
                    }

                    Button {
                        showClearManagedConfirm = true
                    } label: {
                        if isClearingManaged {
                            ProgressView()
                                .tint(TacticalGlassTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        } else {
                            Text("清除一般暫存")
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
                    .disabled(isClearingManaged)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("離線圖說預載")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(0.8)

                            Text(
                                "\(FieldByteCountFormatter.megabytesString(breakdown.offlineDrawingBytes))"
                                    + " / \(FieldByteCountFormatter.megabytesString(offlineBudget))"
                            )
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                            usageBar(ratio: offlineUsageRatio)

                            Text("與上方一般暫存分開計算，不會被自動清理；供離線預覽圖說時使用，可於此清除。")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button {
                        showClearOfflineConfirm = true
                    } label: {
                        if isClearingOffline {
                            ProgressView()
                                .tint(TacticalGlassTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        } else {
                            Text("清除離線圖說預載")
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
                    .disabled(isClearingOffline)
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("說明")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .tracking(0.8)

                        Text("一般暫存為自動快取，可隨時清除；清除後列表與預覽圖會重新下載。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("尚未上傳至伺服器的紀錄與照片不會被清除。")
                            .font(.subheadline)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
        .navigationTitle("儲存空間")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            reloadBreakdown()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldCacheStorageDidChange)) { _ in
            reloadBreakdown()
        }
        .alert("要清除一般暫存嗎？", isPresented: $showClearManagedConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await performClearManaged() }
            }
        } message: {
            Text("將刪除網路與圖片快取，不包含離線圖說預載。不影響尚未上傳的資料。")
        }
        .alert("要清除離線圖說預載嗎？", isPresented: $showClearOfflineConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await performClearOffline() }
            }
        } message: {
            Text("將刪除所有專案已預載的圖說檔案。不影響一般暫存與尚未上傳的資料。")
        }
    }

    private func usageBar(ratio: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.surfaceContainerHighest.opacity(0.5))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.primaryGradient())
                    .frame(width: max(0, geo.size.width * ratio), height: 8)
            }
        }
        .frame(height: 8)
    }

    private var managedBreakdownRows: some View {
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
    private func performClearManaged() async {
        isClearingManaged = true
        defer { isClearingManaged = false }
        FieldCacheStorage.clearAllCaches()
        reloadBreakdown()
    }

    @MainActor
    private func performClearOffline() async {
        isClearingOffline = true
        defer { isClearingOffline = false }
        FieldOfflineDrawingStore.removeAll()
        reloadBreakdown()
    }
}

// MARK: - 設定列表列（摘要）

struct FieldCacheStorageSettingsRow: View {
    @State private var breakdown = FieldCacheStorage.usageBreakdown()

    private var managedBudget: Int64 { FieldCacheStorage.displayBudgetBytes }
    private var offlineBudget: Int64 { FieldOfflineDrawingStore.vaultBudgetBytes() }

    var body: some View {
        NavigationLink {
            FieldCacheStorageDetailView()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("儲存空間")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(
                        "一般暫存 \(FieldByteCountFormatter.megabytesString(breakdown.managedCacheBytes))"
                            + " / \(FieldByteCountFormatter.megabytesString(managedBudget))"
                    )
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    Text(
                        "離線圖說 \(FieldByteCountFormatter.megabytesString(breakdown.offlineDrawingBytes))"
                            + " / \(FieldByteCountFormatter.megabytesString(offlineBudget))"
                    )
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    Text("與圖說預載分開計算 · 點進管理")
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
