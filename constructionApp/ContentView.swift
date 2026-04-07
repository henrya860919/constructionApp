//
//  ContentView.swift
//  constructionApp
//
//  Created by henry chang on 2026/3/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(SessionManager.self) private var session
    @Environment(FieldAppVersionChecker.self) private var versionChecker
    @Environment(\.colorScheme) private var colorScheme

    /// 用於觸發根流程過場（略過連線中狀態的細微變化）。
    private var rootFlowStep: Int {
        if !versionChecker.didFinishLaunchCheck { return 0 }
        if versionChecker.requiresForceUpdate { return 0 }
        if session.isRestoringSession { return 0 }
        if !session.isAuthenticated { return 1 }
        if session.selectedProjectId == nil { return 2 }
        return 3
    }

    private var fieldTheme: FieldThemePalette {
        FieldThemePalette.palette(for: colorScheme)
    }

    var body: some View {
        Group {
            if !versionChecker.didFinishLaunchCheck {
                ZStack {
                    fieldTheme.surface
                        .ignoresSafeArea()
                    ProgressView("檢查更新…")
                        .tint(fieldTheme.primary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if versionChecker.requiresForceUpdate {
                FieldForceUpdateView(appStoreURL: versionChecker.appStoreURL)
                    .transition(.opacity)
            } else if session.isRestoringSession {
                ZStack {
                    fieldTheme.surface
                        .ignoresSafeArea()
                    ProgressView("連線中…")
                        .tint(fieldTheme.primary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if !session.isAuthenticated {
                LoginView()
                    .transition(AppViewMotion.rootContent)
            } else if session.selectedProjectId == nil {
                ProjectPickerView()
                    .transition(AppViewMotion.rootContent)
            } else {
                MainShellView()
                    .transition(AppViewMotion.rootContent)
            }
        }
        .animation(AppViewMotion.rootFlow, value: rootFlowStep)
        .environment(\.fieldTheme, FieldThemePalette.palette(for: colorScheme))
    }
}

#Preview {
    ContentView()
        .environment(SessionManager())
        .environment(FieldAppearanceSettings())
        .environment(FieldAppVersionChecker.shared)
}
