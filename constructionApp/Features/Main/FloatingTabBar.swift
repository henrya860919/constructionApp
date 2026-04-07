//
//  FloatingTabBar.swift
//  constructionApp
//

import SwiftUI

enum FieldModuleTab: Int, CaseIterable, Identifiable {
    case selfInspection
    case deficiency
    case repair
    case drawingManagement
    case dailyLog

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .selfInspection: "查驗"
        case .deficiency: "缺失"
        case .repair: "報修"
        case .drawingManagement: "圖說管理"
        case .dailyLog: "日誌"
        }
    }

    var systemImage: String {
        switch self {
        case .selfInspection: "checklist"
        case .deficiency: "wrench.and.screwdriver"
        case .repair: "hammer"
        case .drawingManagement: "square.grid.2x2"
        case .dailyLog: "doc.text"
        }
    }
}

struct FloatingTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Binding var selection: FieldModuleTab

    private var barRadius: CGFloat { TacticalGlassTheme.cornerRadius + 6 }

    /// 淺色模式玻璃底需用 `onSurface`；深色模式維持 muted 層次。
    private var tabInactiveForeground: Color {
        colorScheme == .light
            ? theme.onSurface.opacity(0.58)
            : theme.mutedLabel.opacity(0.95)
    }

    /// 選中項的**標題**在圖示下方的玻璃底上，須與底對比；勿用 `onPrimary`（僅適用於藍色膠囊上的圖示）。
    private var tabSelectedLabelForeground: Color {
        theme.onSurface
    }

    var body: some View {
        /// Liquid Glass（iOS 26+ SDK）：`GlassEffectContainer` 讓單一長條玻璃與內部選中膠囊在系統內一併合成。
        GlassEffectContainer(spacing: 28) {
            HStack(spacing: 4) {
                ForEach(FieldModuleTab.allCases) { tab in
                    Button {
                        withAnimation(AppViewMotion.moduleTab) {
                            selection = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                if selection == tab {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .fill(theme.primaryGradient())
                                        .frame(width: 44, height: 44)
                                }
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        selection == tab
                                            ? theme.onPrimaryGradientForeground
                                            : tabInactiveForeground
                                    )
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .frame(height: 44)

                            Text(tab.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(
                                    selection == tab
                                        ? tabSelectedLabelForeground
                                        : tabInactiveForeground
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: barRadius, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        /// 玻璃／留白區若未參與 hit test，觸控會穿透到底下列表；全寬底帶加極淡填色與矩形 content shape 攔截整塊區域。
        .background {
            Rectangle()
                .fill(theme.surface.opacity(0.001))
                .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
