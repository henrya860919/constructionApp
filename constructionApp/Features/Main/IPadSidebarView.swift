//
//  IPadSidebarView.swift
//  constructionApp
//
//  iPad regular size class 專用 Sidebar：模組切換 + 專案選擇 + 同步狀態。
//
//  HIG 規範：sidebar 自身**不**自繪 collapse 按鈕。系統 NavigationSplitView 三欄初始化下，會自動在 content 欄 navigation bar leading 提供 sidebar toggle（與 Notes/Mail/Files 一致）。
//

import SwiftUI

struct IPadSidebarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session
    @Environment(FieldOutboxStore.self) private var outbox
    @Environment(FieldNetworkMonitor.self) private var network

    @Binding var selection: FieldModuleTab
    var onOpenSettings: () -> Void
    var onSwitchProject: () -> Void
    var onCollapseSidebar: () -> Void

    private var pendingTotal: Int {
        guard let pid = session.selectedProjectId else { return 0 }
        return outbox.pendingCount(forProjectId: pid)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandRow
                projectPill
                sectionHeader("模組")
                moduleNav
                Color.clear.frame(height: 12)
            }
        }
        .scrollIndicators(.hidden)
        .background(theme.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
        /// 整條 nav bar 隱藏，靠 brandRow 自繪頂部排版（含 NexA 標識 + 收合按鈕）。Sidebar 顯示時 toggle 在這裡 trailing；收合後 sidebar 看不到，toggle 自然消失，由 list 欄左上的展開按鈕接手。
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Brand 列（含右上收合按鈕）

    private var brandRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.primaryGradient())
                    .frame(width: 30, height: 30)
                Text("N")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(theme.onPrimaryGradientForeground)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("NexA")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.onSurface)
                Text("工地日誌")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.mutedLabel)
            }
            Spacer(minLength: 8)
            collapseSidebarButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var collapseSidebarButton: some View {
        Button(action: onCollapseSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.onSurface)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("收合側欄")
        .keyboardShortcut("\\", modifiers: .command)
    }

    // MARK: - Project Pill

    private var projectPill: some View {
        Button(action: onSwitchProject) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.selectedProjectName ?? "尚未選擇專案")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.onSurface)
                        .lineLimit(1)
                    Text(projectSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.mutedLabel)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.mutedLabel)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(theme.surfaceContainer)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .accessibilityLabel("切換專案")
    }

    private var projectSubtitle: String {
        if session.selectedProjectId != nil {
            return "點擊以切換專案"
        }
        return "請先選擇專案"
    }

    // MARK: - Module Nav

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(theme.mutedLabel)
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }

    private var moduleNav: some View {
        VStack(spacing: 2) {
            ForEach(FieldModuleTab.allCases) { tab in
                moduleRow(tab)
            }
        }
        .padding(.horizontal, 8)
    }

    private func moduleRow(_ tab: FieldModuleTab) -> some View {
        let isSelected = (selection == tab)
        return Button {
            withAnimation(AppViewMotion.moduleTab) {
                selection = tab
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? theme.onPrimaryGradientForeground : theme.onSurface.opacity(0.85))
                    .frame(width: 22, height: 22)
                Text(tab.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? theme.onPrimaryGradientForeground : theme.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(theme.primaryGradient()) : AnyShapeStyle(Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            syncStatusPill
            settingsButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surface)
    }

    private var syncStatusPill: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.onSurface)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.surfaceContainer)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        if pendingTotal > 0 {
            Circle()
                .fill(theme.tertiary)
                .frame(width: 7, height: 7)
        } else if network.isReachable {
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.statusSuccess)
        } else {
            Image(systemName: "icloud.slash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.mutedLabel)
        }
    }

    private var statusText: String {
        if pendingTotal > 0 { return "\(pendingTotal) 筆待上傳" }
        return network.isReachable ? "已同步" : "離線中"
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.onSurface)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.surfaceContainer)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("設定")
    }
}
