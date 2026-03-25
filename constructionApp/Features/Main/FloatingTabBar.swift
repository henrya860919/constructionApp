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
    @Binding var selection: FieldModuleTab

    private var barRadius: CGFloat { TacticalGlassTheme.cornerRadius + 6 }

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
                                        .fill(TacticalGlassTheme.primaryGradient())
                                        .frame(width: 44, height: 44)
                                }
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        selection == tab
                                            ? Color.white
                                            : TacticalGlassTheme.mutedLabel.opacity(0.9)
                                    )
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .frame(height: 44)

                            Text(tab.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(
                                    selection == tab
                                        ? Color.white
                                        : TacticalGlassTheme.mutedLabel.opacity(0.8)
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
                .fill(TacticalGlassTheme.surface.opacity(0.001))
                .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
