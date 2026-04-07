//
//  FieldAppearanceSettings.swift
//  constructionApp
//

import Observation
import SwiftUI

enum FieldAppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "跟隨系統"
        case .light: "淺色"
        case .dark: "深色"
        }
    }

    var preferredSwiftUIColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class FieldAppearanceSettings {
    private static let storageKey = "field.appearance.mode"

    var mode: FieldAppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        mode = FieldAppearanceMode(rawValue: raw) ?? .system
    }
}
