//
//  MainShellView.swift
//  constructionApp
//

import SwiftUI

struct MainShellView: View {
    @Environment(SessionManager.self) private var session
    @State private var tab: FieldModuleTab = .selfInspection

    var body: some View {
        NavigationStack {
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
                .padding(.bottom, 88)
                .animation(AppViewMotion.moduleTab, value: tab)

                FloatingTabBar(selection: $tab)
                    .padding(.bottom, 6)
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
        .tint(TacticalGlassTheme.primary)
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
        case .dailyLog:
            DailyLogHomeView()
        }
    }
}
