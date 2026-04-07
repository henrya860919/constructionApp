//
//  FieldSettingsView.swift
//  constructionApp
//

import SwiftUI

// MARK: - Toolbar avatar

struct AccountToolbarAvatar: View {
    @Environment(\.fieldTheme) private var theme
    let user: AuthUser?
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.primaryGradient())
            Text(initials)
                .font(.system(size: max(12, size * 0.36), weight: .bold))
                .foregroundStyle(theme.onPrimaryGradientForeground)
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .strokeBorder(theme.ghostBorder, lineWidth: 1)
        }
        .accessibilityLabel("帳號與設定")
    }

    private var initials: String {
        guard let user else { return "?" }
        let t = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count >= 2 {
            let chars = t.prefix(2)
            return String(chars).uppercased()
        }
        if let c = t.first {
            return String(c).uppercased()
        }
        if let c = user.email.first {
            return String(c).uppercased()
        }
        return "?"
    }
}

// MARK: - Settings

struct FieldSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(FieldAppearanceSettings.self) private var appearanceSettings
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var storageBreakdown = FieldCacheStorage.usageBreakdown()

    var body: some View {
        @Bindable var appearanceSettings = appearanceSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = session.currentUser {
                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("個人資訊")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.mutedLabel)
                                .tracking(0.8)

                            HStack(alignment: .center, spacing: 14) {
                                AccountToolbarAvatar(user: user, size: 52)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(theme.onSurface)
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.mutedLabel)
                                    Text(profileStorageSummary)
                                        .font(.caption2)
                                        .foregroundStyle(theme.mutedLabel.opacity(0.95))
                                        .padding(.top, 2)
                                }
                                Spacer(minLength: 0)
                            }

                            labeledRow(title: "角色", value: systemRoleLabel(user.systemRole))
                            if let tid = user.tenantId, !tid.isEmpty {
                                labeledRow(title: "租戶 ID", value: tid, mono: true)
                            }
                        }
                    }
                }

                TacticalGlassCard {
                    FieldCacheStorageSettingsRow()
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("外觀")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.mutedLabel)
                            .tracking(0.8)
                        Picker("介面外觀", selection: $appearanceSettings.mode) {
                            ForEach(FieldAppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("介面外觀")
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("當前專案")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.mutedLabel)
                            .tracking(0.8)

                        Text(session.selectedProjectName ?? "未選擇")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.onSurface)

                        if let id = session.selectedProjectId {
                            Text(id)
                                .font(.tacticalMonoFixed(size: 12, weight: .medium))
                                .foregroundStyle(theme.mutedLabel)
                                .lineLimit(2)
                        }

                        Button {
                            session.clearProjectSelection()
                        } label: {
                            Text("切換專案")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TacticalSecondaryButtonStyle())
                    }
                }

                Button(role: .destructive) {
                    session.logout()
                } label: {
                    Text("登出")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.statusDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(theme.statusDanger.opacity(0.14))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(theme.statusDanger.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(theme.surface)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("關閉") {
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.primary)
            }
        }
        .onAppear {
            storageBreakdown = FieldCacheStorage.usageBreakdown()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldCacheStorageDidChange)) { _ in
            storageBreakdown = FieldCacheStorage.usageBreakdown()
        }
    }

    private var profileStorageSummary: String {
        let m = FieldByteCountFormatter.megabytesString(storageBreakdown.managedCacheBytes)
        let mb = FieldByteCountFormatter.megabytesString(FieldCacheStorage.displayBudgetBytes)
        let o = FieldByteCountFormatter.megabytesString(storageBreakdown.offlineDrawingBytes)
        let ob = FieldByteCountFormatter.megabytesString(FieldOfflineDrawingStore.vaultBudgetBytes())
        return "本機：一般暫存 \(m)／\(mb) · 離線圖說 \(o)／\(ob)"
    }

    private func labeledRow(title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(0.5)
            if mono {
                Text(value)
                    .font(.tacticalMonoFixed(size: 12, weight: .medium))
                    .foregroundStyle(theme.onSurface.opacity(0.9))
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(theme.onSurface.opacity(0.9))
            }
        }
        .padding(.top, 4)
    }

    private func systemRoleLabel(_ role: String) -> String {
        switch role {
        case "platform_admin": return "平台管理員"
        case "tenant_admin": return "租戶管理員"
        case "project_user": return "專案使用者"
        default: return role
        }
    }
}
