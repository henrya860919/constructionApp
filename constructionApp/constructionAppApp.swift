//
//  constructionAppApp.swift
//  constructionApp
//
//  Created by henry chang on 2026/3/25.
//

import SwiftUI

@main
struct constructionAppApp: App {
    @UIApplicationDelegateAdaptor(FieldAppDelegate.self) private var appDelegate
    @State private var session = SessionManager()

    init() {
        FieldCacheStorage.configureAtLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .environment(FieldNetworkMonitor.shared)
                .environment(FieldOutboxStore.shared)
                .environment(FieldAppVersionChecker.shared)
                .task {
                    await FieldAppVersionChecker.shared.evaluateAtLaunch()
                    if !FieldAppVersionChecker.shared.requiresForceUpdate {
                        await session.bootstrap()
                    }
                }
        }
    }
}
