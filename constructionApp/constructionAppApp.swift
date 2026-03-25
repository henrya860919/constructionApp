//
//  constructionAppApp.swift
//  constructionApp
//
//  Created by henry chang on 2026/3/25.
//

import SwiftUI

@main
struct constructionAppApp: App {
    @State private var session = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .task {
                    await session.bootstrap()
                }
        }
    }
}
