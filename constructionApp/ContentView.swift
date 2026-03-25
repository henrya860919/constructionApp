//
//  ContentView.swift
//  constructionApp
//
//  Created by henry chang on 2026/3/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(SessionManager.self) private var session

    /// 用於觸發根流程過場（略過連線中狀態的細微變化）。
    private var rootFlowStep: Int {
        if session.isRestoringSession { return 0 }
        if !session.isAuthenticated { return 1 }
        if session.selectedProjectId == nil { return 2 }
        return 3
    }

    var body: some View {
        Group {
            if session.isRestoringSession {
                ZStack {
                    TacticalGlassTheme.surface
                        .ignoresSafeArea()
                    ProgressView("連線中…")
                        .tint(TacticalGlassTheme.primary)
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
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environment(SessionManager())
}
