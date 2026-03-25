//
//  FieldSettingsView.swift
//  constructionApp
//

import SwiftUI

// MARK: - Toolbar avatar

struct AccountToolbarAvatar: View {
    let user: AuthUser?
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(TacticalGlassTheme.primaryGradient())
            Text(initials)
                .font(.system(size: max(12, size * 0.36), weight: .bold))
                .foregroundStyle(Color.black.opacity(0.88))
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
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
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = session.currentUser {
                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("個人資訊")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(0.8)

                            HStack(alignment: .center, spacing: 14) {
                                AccountToolbarAvatar(user: user, size: 52)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("當前專案")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .tracking(0.8)

                        Text(session.selectedProjectName ?? "未選擇")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        if let id = session.selectedProjectId {
                            Text(id)
                                .font(.tacticalMonoFixed(size: 12, weight: .medium))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
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
                        .foregroundStyle(TacticalGlassTheme.statusDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(TacticalGlassTheme.statusDanger.opacity(0.14))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(TacticalGlassTheme.statusDanger.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("關閉") {
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
    }

    private func labeledRow(title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(0.5)
            if mono {
                Text(value)
                    .font(.tacticalMonoFixed(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
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
