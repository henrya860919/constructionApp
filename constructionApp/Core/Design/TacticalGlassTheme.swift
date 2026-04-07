//
//  TacticalGlassTheme.swift
//  constructionApp
//
//  版面與字距常數。語意色彩請用 `@Environment(\.fieldTheme)` → `FieldThemePalette`。
//

import SwiftUI

enum TacticalGlassTheme {
    static let cornerRadius: CGFloat = 12

    static let tabBarScrollBottomMargin: CGFloat = 88

    static let fieldFABBottomInset: CGFloat = tabBarScrollBottomMargin + 18

    static func headlineKerning(forSize points: CGFloat) -> CGFloat {
        -0.02 * points
    }
}

/// 規格 body-md 14pt；若專案內嵌 Inter，可改為 `.custom("Inter-Regular", size: 14)` 等。
enum FieldTypography {
    static func bodyMD(weight: Font.Weight = .regular) -> Font {
        .system(size: 14, weight: weight, design: .default)
    }
}
