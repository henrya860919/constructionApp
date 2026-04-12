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
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session
    @State private var model = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            FieldAmbientBackground()

            ScrollView {
                VStack(spacing: 28) {
                    header

                    TacticalGlassCard(cornerRadius: 28, elevated: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            TacticalTextField(
                                title: "Email",
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
                                Label(err, systemImage: "exclamationmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.tertiary)
                                    .accessibilityLabel("錯誤：\(err)")
                            }

                            Button {
                                Task { await model.submit(session: session) }
                            } label: {
                                HStack(spacing: 10) {
                                    if model.isLoading {
                                        ProgressView()
                                            .tint(theme.onPrimary)
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.headline)
                                    }
                                    Text(model.isLoading ? "登入中…" : "登入")
                                }
                            }
                            .buttonStyle(TacticalPrimaryButtonStyle())
                            .disabled(model.isLoading)
                            .accessibilityHint("送出登入表單")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var header: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .accessibilityLabel("NexA Logo")
    }
}

#Preview {
    LoginView()
        .environment(SessionManager())
        .environment(FieldAppearanceSettings())
        .preferredColorScheme(.light)
        .fieldThemePalette(FieldThemePalette.palette(for: .light))
}
