//
//  MainShellView.swift
//  constructionApp
//

import SwiftUI

struct MainShellView: View {
    @Environment(SessionManager.self) private var session
    @Environment(FieldOutboxStore.self) private var outbox
    @Environment(FieldNetworkMonitor.self) private var network
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: FieldModuleTab = .selfInspection
    @State private var syncAcknowledgementBanner: String?

    var body: some View {
        /// Tab Bar 必須在 `NavigationStack` 的根內容樹裡（與模組同層），`push` 詳情／設定時才會被蓋住；若放在 Stack 外層 `ZStack` 則會永遠浮在所有頁面上。
        NavigationStack {
            VStack(spacing: 0) {
                FieldOfflineBanner()
                ZStack(alignment: .bottom) {
                    ZStack {
                        ForEach(FieldModuleTab.allCases) { module in
                            if tab == module {
                                moduleRootView(for: module)
                                    .transition(AppViewMotion.moduleContent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    FloatingTabBar(selection: $tab)
                }
                .animation(AppViewMotion.moduleTab, value: tab)
            }
            .background(TacticalGlassTheme.surface)
            .navigationTitle(session.selectedProjectName ?? "專案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FieldSettingsView()
                    } label: {
                        AccountToolbarAvatar(user: session.currentUser)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(TacticalGlassTheme.primary)
        .overlay(alignment: .top) {
            if let text = syncAcknowledgementBanner {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TacticalGlassTheme.onPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background {
                        Capsule(style: .continuous)
                            .fill(TacticalGlassTheme.primary.opacity(0.94))
                    }
                    .padding(.top, 10)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: syncAcknowledgementBanner)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                FieldCacheStorage.trimIfNeeded()
                Task { await syncOutboxIfPossible(triggerListRefreshAfterReachability: false) }
            }
        }
        .onAppear {
            FieldCacheStorage.trimIfNeeded()
            Task { await syncOutboxIfPossible(triggerListRefreshAfterReachability: false) }
        }
        .onChange(of: network.isReachable) { _, online in
            if online {
                Task { await syncOutboxIfPossible(triggerListRefreshAfterReachability: true) }
            }
        }
    }

    /// 同步離線佇列；必要時廣播列表重新載入並顯示應用內提示（補足前景時系統推播不顯示的問題）。
    private func syncOutboxIfPossible(triggerListRefreshAfterReachability: Bool) async {
        guard session.isAuthenticated else { return }
        let token: String
        do {
            token = try await session.withValidAccessToken { $0 }
        } catch {
            return
        }
        let r = await outbox.syncOutbox(baseURL: AppConfiguration.apiRootURL, token: token)
        let shouldRefreshLists =
            r.removedCount > 0
            || (triggerListRefreshAfterReachability && FieldNetworkMonitor.shared.isReachable)
        if shouldRefreshLists {
            NotificationCenter.default.post(name: .fieldRemoteDataShouldRefresh, object: nil)
        }
        if r.removedCount > 0 {
            let msg: String
            if r.hadPendingAtStart && r.queueNowEmpty {
                msg = "待上傳項目已全部同步至伺服器"
            } else {
                msg = "已同步 \(r.removedCount) 筆至伺服器"
            }
            await MainActor.run {
                withAnimation { syncAcknowledgementBanner = msg }
            }
            let shown = msg
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                if syncAcknowledgementBanner == shown {
                    withAnimation { syncAcknowledgementBanner = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func moduleRootView(for module: FieldModuleTab) -> some View {
        switch module {
        case .selfInspection:
            SelfInspectionHomeView()
        case .deficiency:
            DeficiencyModuleView()
        case .repair:
            RepairHomeView()
        case .drawingManagement:
            DrawingManagementHomeView()
        case .dailyLog:
            DailyLogHomeView()
        }
    }
}
