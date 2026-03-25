//
//  LoginView.swift
//  constructionApp
//

import SwiftUI

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    func submit(session: SessionManager) async {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "請輸入 Email"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "請輸入密碼"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await session.login(email: email, password: password)
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct LoginView: View {
    @Environment(SessionManager.self) private var session
    @State private var model = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            TacticalGlassTheme.surface
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    TacticalGlassTheme.surfaceContainerLow.opacity(0.4),
                    TacticalGlassTheme.surface,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TacticalTextField(
                                title: "帳號",
                                text: $model.email,
                                keyboard: .emailAddress,
                                contentType: .username
                            )
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                            TacticalTextField(
                                title: "密碼",
                                text: $model.password,
                                contentType: .password,
                                isSecure: true
                            )
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await model.submit(session: session) } }

                            if let err = model.errorMessage {
                                Text(err)
                                    .font(.subheadline)
                                    .foregroundStyle(TacticalGlassTheme.tertiary)
                                    .accessibilityLabel("錯誤：\(err)")
                            }

                            Button {
                                Task { await model.submit(session: session) }
                            } label: {
                                if model.isLoading {
                                    ProgressView()
                                        .tint(TacticalGlassTheme.onPrimary)
                                } else {
                                    Text("登入")
                                }
                            }
                            .buttonStyle(TacticalPrimaryButtonStyle())
                            .disabled(model.isLoading)
                            .accessibilityHint("送出登入表單")
                        }
                    }

                    apiHint
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FIELD COMMAND")
                .font(.caption.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.primary)
                .tracking(2)

            Text("現場指揮")
                .tacticalDisplay(32, weight: .bold)
                .foregroundStyle(.white)

            Text("自主查驗 · 缺失改善 · 報修 · 施工日誌")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(AppDateDisplay.string(from: Date.now))
                .font(.tacticalMono(.subheadline, weight: .medium))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .padding(.top, 4)
        }
    }

    private var apiHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("API")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(AppConfiguration.apiRootURL.absoluteString)
                .font(.tacticalMonoFixed(size: 11, weight: .regular))
                .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                .textSelection(.enabled)
        }
        .padding(.top, 8)
    }
}

#Preview {
    LoginView()
        .environment(SessionManager())
}
