//
//  ProjectPickerView.swift
//  constructionApp
//

import SwiftUI

@MainActor
@Observable
final class ProjectPickerViewModel {
    var projects: [ProjectSummary] = []
    var isLoading = false
    var errorMessage: String?

    func load(session: SessionManager) async {
        guard let token = session.accessToken else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            projects = try await APIService.listProjects(
                baseURL: AppConfiguration.apiRootURL,
                token: token
            )
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct ProjectPickerView: View {
    @Environment(SessionManager.self) private var session
    @State private var model = ProjectPickerViewModel()

    var body: some View {
        ZStack {
            TacticalGlassTheme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("選擇專案")
                            .tacticalTitle(26, weight: .bold)
                            .foregroundStyle(.white)

                        Text("對應網頁版專案工作區 `/p/:projectId`")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let user = session.currentUser {
                            Text(user.name.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TacticalGlassTheme.primary)
                                .tracking(1.2)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 4)

                    if model.isLoading {
                        ProgressView()
                            .tint(TacticalGlassTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if let err = model.errorMessage {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(TacticalGlassTheme.tertiary)
                            .padding(.vertical, 8)
                    } else if model.projects.isEmpty {
                        Text("尚無可存取專案")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(model.projects) { project in
                                Button {
                                    session.selectProject(id: project.id, name: project.name)
                                } label: {
                                    projectRow(project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button("登出") {
                        session.logout()
                    }
                    .buttonStyle(TacticalSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
                .padding(24)
            }
        }
        .task {
            await model.load(session: session)
        }
    }

    private func projectRow(_ project: ProjectSummary) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    Text("ID")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Text(project.id)
                        .font(.tacticalMonoFixed(size: 11, weight: .medium))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let code = project.code, !code.isEmpty {
                    Text(code)
                        .font(.tacticalMono(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.75))
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainer)
        }
    }
}

#Preview {
    ProjectPickerView()
        .environment(SessionManager())
}
