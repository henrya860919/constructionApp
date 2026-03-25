//
//  AppViewTransitions.swift
//  constructionApp
//

import SwiftUI

/// 全 App 共用的過場曲線與 transition（主分頁、根流程切換）。
enum AppViewMotion {
    /// 底部四格模組切換
    static let moduleTab = Animation.spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0)

    /// 登入 → 選專案 → 主工作區
    static let rootFlow = Animation.easeInOut(duration: 0.34)

    /// 模組內容：淡入＋微縮放（不依賴左右滑方向）
    static var moduleContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97)),
            removal: .opacity.combined(with: .scale(scale: 1.02))
        )
    }

    /// 根層級畫面：淡入＋自右側滑入
    static var rootContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }
}
