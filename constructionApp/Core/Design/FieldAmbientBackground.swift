//
//  FieldAmbientBackground.swift
//  constructionApp
//

import SwiftUI

/// Full-screen backdrop for auth and other standalone field screens.
struct FieldAmbientBackground: View {
    @Environment(\.fieldTheme) private var theme

    var body: some View {
        LinearGradient(
            colors: [
                theme.surfaceContainerLowest,
                theme.surface,
                theme.surfaceContainerHigh.opacity(0.9),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    FieldAmbientBackground()
        .fieldThemePalette(FieldThemePalette.palette(for: .light))
}
