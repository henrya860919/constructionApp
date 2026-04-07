//
//  FieldThemePalette.swift
//  constructionApp
//
//  Tactical Architect — semantic colors (light / dark).
//  擴充：新增靜態 palette，或在 `palette(for:variant:)` 依 `FieldThemeVariant` 分支。
//

import SwiftUI

enum FieldThemeVariant: String, Sendable {
    case tacticalArchitect
}

private extension Color {
    init(rgb: UInt32, alpha: Double = 1) {
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: alpha)
    }
}

struct FieldThemePalette: Sendable, Equatable {
    let surface: Color
    let surfaceContainerLow: Color
    let surfaceContainerLowest: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color

    let primary: Color
    let primaryContainer: Color
    let onPrimary: Color
    let onPrimaryGradientForeground: Color

    let secondary: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color

    let accentHighVisibility: Color

    let tertiary: Color
    let onSurface: Color
    let mutedLabel: Color

    let statusSuccess: Color
    let statusDanger: Color

    let outlineVariant: Color

    var ghostBorder: Color { outlineVariant.opacity(0.15) }

    var ambientShadow: Color { Color(red: 26 / 255, green: 28 / 255, blue: 28 / 255).opacity(0.06) }

    func primaryGradient() -> LinearGradient {
        LinearGradient(
            colors: [primary, primaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func palette(for scheme: ColorScheme, variant: FieldThemeVariant = .tacticalArchitect) -> FieldThemePalette {
        switch variant {
        case .tacticalArchitect:
            switch scheme {
            case .light: .lightTacticalArchitect
            case .dark: .darkTacticalArchitect
            @unknown default: .lightTacticalArchitect
            }
        }
    }

    private static let lightTacticalArchitect = FieldThemePalette(
        surface: Color(rgb: 0xDADADA),
        surfaceContainerLow: Color(rgb: 0xE4E6EA),
        surfaceContainerLowest: Color(rgb: 0xFFFFFF),
        surfaceContainer: Color(rgb: 0xECEEF2),
        surfaceContainerHigh: Color(rgb: 0xD8DCE2),
        surfaceContainerHighest: Color(rgb: 0xE2E6EC),
        primary: Color(rgb: 0x004DB5),
        primaryContainer: Color(rgb: 0x0064E6),
        onPrimary: .white,
        onPrimaryGradientForeground: .white,
        secondary: Color(rgb: 0x006B5E),
        secondaryContainer: Color(rgb: 0xC8FFF5),
        onSecondaryContainer: Color(rgb: 0x00332C),
        accentHighVisibility: Color(rgb: 0x00EBD0),
        tertiary: Color(rgb: 0xC27D00),
        onSurface: Color(rgb: 0x1A1C1C),
        mutedLabel: Color(rgb: 0x5C6370),
        statusSuccess: Color(rgb: 0x0D8A4A),
        statusDanger: Color(rgb: 0xD93025),
        outlineVariant: Color(rgb: 0x6B7280)
    )

    private static let darkTacticalArchitect = FieldThemePalette(
        surface: Color(rgb: 0x0B0F14),
        surfaceContainerLow: Color(rgb: 0x121820),
        surfaceContainerLowest: Color(rgb: 0x151B24),
        surfaceContainer: Color(rgb: 0x1A222C),
        surfaceContainerHigh: Color(rgb: 0x202A36),
        surfaceContainerHighest: Color(rgb: 0x283240),
        primary: Color(rgb: 0x3B82F6),
        primaryContainer: Color(rgb: 0x0064E6),
        onPrimary: .white,
        onPrimaryGradientForeground: .white,
        secondary: Color(rgb: 0x2DD4BF),
        secondaryContainer: Color(rgb: 0x003D38),
        onSecondaryContainer: Color(rgb: 0x8FFCEB),
        accentHighVisibility: Color(rgb: 0x00EBD0),
        tertiary: Color(rgb: 0xFBBF24),
        onSurface: Color(rgb: 0xE8EAED),
        mutedLabel: Color(rgb: 0x9AA4B2),
        statusSuccess: Color(rgb: 0x34D399),
        statusDanger: Color(rgb: 0xF87171),
        outlineVariant: Color(rgb: 0x5C6570)
    )
}

private enum FieldThemeKey: EnvironmentKey {
    static let defaultValue = FieldThemePalette.palette(for: .light)
}

extension EnvironmentValues {
    var fieldTheme: FieldThemePalette {
        get { self[FieldThemeKey.self] }
        set { self[FieldThemeKey.self] = newValue }
    }
}

extension View {
    func fieldThemePalette(_ palette: FieldThemePalette) -> some View {
        environment(\.fieldTheme, palette)
    }
}
