//
//  ProjectPickerView.swift
//  constructionApp
//

import SwiftUI

@MainActor
@Observable
final class ProjectPickerViewModel {
    var projects: [ProjectSummary] = []
    var listMeta: ProjectListResponse.Meta?
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    var hasMore: Bool {
        guard let m = listMeta else { return false }
        return projects.count < m.total
    }

    func load(session: SessionManager) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await session.withValidAccessToken { token in
                try await APIService.listProjects(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    page: 1,
                    limit: FieldListPagination.pageSize
                )
            }
            projects = page.data
            listMeta = page.meta
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(session: SessionManager) async {
        guard let m = listMeta, hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = m.page + 1
        do {
            let page = try await session.withValidAccessToken { token in
                try await APIService.listProjects(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    page: nextPage,
                    limit: FieldListPagination.pageSize
                )
            }
            let existing = Set(projects.map(\.id))
            let newItems = page.data.filter { !existing.contains($0.id) }
            projects.append(contentsOf: newItems)
            listMeta = page.meta
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct ProjectPickerView: View {
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session
    @State private var model = ProjectPickerViewModel()

    var body: some View {
        ZStack {
            theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("選擇專案")
                            .tacticalTitle(26, weight: .bold)
                            .foregroundStyle(theme.onSurface)
                    }
                    .padding(.horizontal, 4)

                    if model.isLoading {
                        ProgressView()
                            .tint(theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if let err = model.errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(theme.tertiary)
                                Text("無法載入專案")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.onSurface)
                            }
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(theme.mutedLabel)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("重試") {
                                Task { await model.load(session: session) }
                            }
                            .buttonStyle(TacticalSecondaryButtonStyle())
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(theme.surfaceContainer.opacity(0.95))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(theme.tertiary.opacity(0.35), lineWidth: 1)
                        }
                    } else if model.projects.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.title2)
                                .foregroundStyle(theme.mutedLabel)
                            Text("尚無可存取專案")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
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
                            if model.hasMore {
                                Button {
                                    Task { await model.loadMore(session: session) }
                                } label: {
                                    HStack {
                                        if model.isLoadingMore {
                                            ProgressView()
                                                .tint(theme.primary)
                                        }
                                        Text(model.isLoadingMore ? "載入中…" : "載入更多")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(theme.primary)
                                .disabled(model.isLoadingMore)
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
            .scrollDismissesKeyboard(.immediately)
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
                        .foregroundStyle(theme.mutedLabel)
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
                .foregroundStyle(theme.mutedLabel.opacity(0.75))
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(theme.surfaceContainer)
        }
    }
}

#Preview {
    ProjectPickerView()
        .environment(SessionManager())
        .environment(FieldAppearanceSettings())
        .fieldThemePalette(FieldThemePalette.palette(for: .light))
}
