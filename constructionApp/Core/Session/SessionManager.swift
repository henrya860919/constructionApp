//
//  SessionManager.swift
//  constructionApp
//

import Foundation
import Observation
import UserNotifications

enum FieldSessionAuthError: Error, LocalizedError {
    case notSignedIn
    case refreshFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "請先登入"
        case .refreshFailed:
            "登入已過期，請重新登入"
        }
    }
}

@MainActor
@Observable
final class SessionManager {
    private(set) var isRestoringSession = true
    private(set) var isAuthenticated = false
    private(set) var accessToken: String?
    private(set) var currentUser: AuthUser?

    var selectedProjectId: String?
    var selectedProjectName: String?

    private let defaults = UserDefaults.standard
    private let projectIdKey = "field.selectedProjectId"
    private let projectNameKey = "field.selectedProjectName"
    private let cachedUserKey = "field.cachedAuthUserJSON"

    init() {
        selectedProjectId = defaults.string(forKey: projectIdKey)
        selectedProjectName = defaults.string(forKey: projectNameKey)
    }

    /// 取得有效 access token：必要時依 `exp` 先 refresh；API 回 401 時最多再 refresh 一次後重試。
    func withValidAccessToken<T: Sendable>(
        _ body: @escaping @Sendable (String) async throws -> T
    ) async throws -> T {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()

        func tokenAfterProactiveRefresh() async throws -> String {
            var token = accessToken ?? KeychainHelper.readToken()
            guard let t0 = token, !t0.isEmpty else { throw FieldSessionAuthError.notSignedIn }
            if KeychainHelper.readRefreshToken() != nil, FieldJWT.shouldProactivelyRefresh(jwt: t0) {
                try await refreshAccessTokenIfPossible()
                token = accessToken ?? KeychainHelper.readToken()
            }
            guard let out = token, !out.isEmpty else { throw FieldSessionAuthError.notSignedIn }
            return out
        }

        let first = try await tokenAfterProactiveRefresh()
        do {
            return try await body(first)
        } catch let api as APIRequestError {
            if case .httpStatus(401, _) = api, KeychainHelper.readRefreshToken() != nil {
                try await refreshAccessTokenIfPossible()
                let second = try await tokenAfterProactiveRefresh()
                return try await body(second)
            }
            throw api
        }
    }

    private func refreshAccessTokenIfPossible() async throws {
        guard let refresh = KeychainHelper.readRefreshToken() else {
            throw FieldSessionAuthError.refreshFailed
        }
        let part = try await APIService.refreshSessionTokens(
            baseURL: AppConfiguration.apiRootURL,
            refreshToken: refresh
        )
        KeychainHelper.saveToken(part.accessToken)
        KeychainHelper.saveRefreshToken(part.refreshToken)
        accessToken = part.accessToken
    }

    func bootstrap() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        guard KeychainHelper.readToken() != nil else {
            clearSessionState(preserveProjectSelection: true)
            return
        }
        accessToken = KeychainHelper.readToken()

        do {
            let user = try await withValidAccessToken { token in
                try await APIService.fetchMe(baseURL: AppConfiguration.apiRootURL, token: token)
            }
            currentUser = user
            isAuthenticated = true
            persistCachedUser(user)
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            if error is FieldSessionAuthError {
                KeychainHelper.deleteAllAuthSecrets()
                defaults.removeObject(forKey: cachedUserKey)
                clearSessionState(preserveProjectSelection: true)
                return
            }
            if let api = error as? APIRequestError, case let .httpStatus(code, _) = api, code == 401 {
                KeychainHelper.deleteAllAuthSecrets()
                defaults.removeObject(forKey: cachedUserKey)
                clearSessionState(preserveProjectSelection: true)
                return
            }
            if error.isLikelyConnectivityFailure, let cached = loadCachedUser() {
                currentUser = cached
                isAuthenticated = true
                return
            }
            KeychainHelper.deleteAllAuthSecrets()
            defaults.removeObject(forKey: cachedUserKey)
            clearSessionState(preserveProjectSelection: true)
        }
        if isAuthenticated {
            await FieldRemoteNotifications.registerWithAPNsIfAuthorized()
        }
    }

    func login(email: String, password: String) async throws {
        let result = try await APIService.login(
            baseURL: AppConfiguration.apiRootURL,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        KeychainHelper.saveToken(result.accessToken)
        if let r = result.refreshToken, !r.isEmpty {
            KeychainHelper.saveRefreshToken(r)
        } else {
            KeychainHelper.deleteRefreshToken()
        }
        accessToken = result.accessToken
        currentUser = result.user
        isAuthenticated = true
        persistCachedUser(result.user)
        await requestNotificationAuthorizationIfNeeded()
    }

    /// 登入成功後向使用者詢問是否允許通知（橫幅／遠端推播）；已決定過則不再跳出系統詢問。
    private func requestNotificationAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        await FieldRemoteNotifications.registerWithAPNsIfAuthorized()
    }

    func logout() {
        let base = AppConfiguration.apiRootURL
        let token = accessToken ?? KeychainHelper.readToken()
        if let token {
            Task {
                try? await APIService.logout(baseURL: base, token: token)
            }
        }
        KeychainHelper.deleteAllAuthSecrets()
        defaults.removeObject(forKey: cachedUserKey)
        clearSessionState(preserveProjectSelection: false)
    }

    func selectProject(id: String, name: String) {
        selectedProjectId = id
        selectedProjectName = name
        defaults.set(id, forKey: projectIdKey)
        defaults.set(name, forKey: projectNameKey)
    }

    func clearProjectSelection() {
        selectedProjectId = nil
        selectedProjectName = nil
        defaults.removeObject(forKey: projectIdKey)
        defaults.removeObject(forKey: projectNameKey)
    }

    private func clearSessionState(preserveProjectSelection: Bool) {
        accessToken = nil
        currentUser = nil
        isAuthenticated = false
        if !preserveProjectSelection {
            clearProjectSelection()
        }
    }

    private func persistCachedUser(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: cachedUserKey)
        }
    }

    private func loadCachedUser() -> AuthUser? {
        guard let data = defaults.data(forKey: cachedUserKey) else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }
}
