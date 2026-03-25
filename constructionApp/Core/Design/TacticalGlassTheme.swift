//
//  TacticalGlassTheme.swift
//  constructionApp
//
//  Tactical Obsidian — tokens aligned with `.cursor/rules/tactical-obsidian-design.mdc`.
//

import SwiftUI

enum TacticalGlassTheme {
    /// Unified corner radius for cards, buttons, FAB (12pt).
    static let cornerRadius: CGFloat = 12

    /// 列表頁 FAB 距螢幕底；愈小愈靠近 tab bar（與 `MainShellView` 底部預留搭配）。
    static let fieldFABBottomInset: CGFloat = 50

    /// Page base — Obsidian `#0B0E11`
    static let surface = Color(red: 11 / 255, green: 14 / 255, blue: 17 / 255)

    /// Major sections `#101417`
    static let surfaceContainerLow = Color(red: 16 / 255, green: 20 / 255, blue: 23 / 255)

    /// Recessed inputs — slightly below low
    static let surfaceContainerLowest = Color(red: 10 / 255, green: 13 / 255, blue: 16 / 255)

    /// Cards / rows `#161A1E`
    static let surfaceContainer = Color(red: 22 / 255, green: 26 / 255, blue: 30 / 255)

    /// Elevated chrome `#22262B`
    static let surfaceContainerHighest = Color(red: 34 / 255, green: 38 / 255, blue: 43 / 255)

    /// Legacy alias — prefer `surfaceContainer` for new UI
    static let surfaceContainerHigh = surfaceContainer

    /// Safety orange — `#FF915D`
    static let primary = Color(red: 255 / 255, green: 145 / 255, blue: 93 / 255)

    /// Gradient end / deeper orange — `#FF7936`
    static let primaryContainer = Color(red: 255 / 255, green: 121 / 255, blue: 54 / 255)

    static let onPrimary = Color.white

    /// Muted label / metadata (~ `#8E8E93`)
    static let mutedLabel = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)

    /// Warning / pending accent — `#FFD600`
    static let tertiary = Color(red: 255 / 255, green: 214 / 255, blue: 0 / 255)

    /// Pass / resolved
    static let statusSuccess = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)

    /// Critical / fail
    static let statusDanger = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)

    /// Ghost border base `#45484C` @ 15% (spec)
    static let outlineVariant = Color(red: 69 / 255, green: 72 / 255, blue: 76 / 255)

    static var ghostBorder: Color { outlineVariant.opacity(0.15) }

    /// Ambient lift — subtle, warm-tinted (not heavy gray drop shadow)
    static var ambientShadow: Color { primary.opacity(0.06) }

    static func primaryGradient() -> LinearGradient {
        LinearGradient(
            colors: [primary, primaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Headline tracking ≈ -0.02em
    static func headlineKerning(forSize points: CGFloat) -> CGFloat {
        -0.02 * points
    }

    // MARK: - Legacy names (compatibility)

    /// Former “compliance blue” — Obsidian UI now uses orange/gray; keep for any straggler imports.
    static let secondary = mutedLabel

    static var secondaryMuted: Color { mutedLabel.opacity(0.35) }

    static let primaryDeep = primaryContainer
}
