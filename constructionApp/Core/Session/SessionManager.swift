//
//  SessionManager.swift
//  constructionApp
//

import Foundation
import Observation

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

    init() {
        selectedProjectId = defaults.string(forKey: projectIdKey)
        selectedProjectName = defaults.string(forKey: projectNameKey)
    }

    func bootstrap() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        guard let token = KeychainHelper.readToken() else {
            clearSessionState(preserveProjectSelection: true)
            return
        }
        accessToken = token
        do {
            let user = try await APIService.fetchMe(baseURL: AppConfiguration.apiRootURL, token: token)
            currentUser = user
            isAuthenticated = true
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            KeychainHelper.deleteToken()
            clearSessionState(preserveProjectSelection: true)
        }
    }

    func login(email: String, password: String) async throws {
        let result = try await APIService.login(
            baseURL: AppConfiguration.apiRootURL,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        KeychainHelper.saveToken(result.token)
        accessToken = result.token
        currentUser = result.user
        isAuthenticated = true
    }

    func logout() {
        KeychainHelper.deleteToken()
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
}
