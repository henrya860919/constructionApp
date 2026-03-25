//
//  DeficiencyModuleView.swift
//  constructionApp
//
//  缺失紀錄 — 列表／詳情／新增；UI 參考 SITE_OPS 戰術深色稿與 Tactical Obsidian 規範。
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private func defectUniqIdsPreservingOrder(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    out.reserveCapacity(ids.count)
    for id in ids where seen.insert(id).inserted {
        out.append(id)
    }
    return out
}

private func defectMimeForImageData(data: Data, fallbackExtension: String) -> String {
    if fallbackExtension.lowercased() == "png" { return "image/png" }
    if fallbackExtension.lowercased() == "heic" || fallbackExtension.lowercased() == "heif" {
        return "image/heic"
    }
    if data.count >= 2, data[0] == 0xFF, data[1] == 0xD8 { return "image/jpeg" }
    if data.count >= 8, data[0] == 0x89, data[1] == 0x50 { return "image/png" }
    return "image/jpeg"
}

// MARK: - Filters

enum DefectStatusFilter: String, CaseIterable, Identifiable {
    case all
    case inProgress
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .inProgress: "進行中"
        case .completed: "已完成"
        }
    }

    var queryValue: String? {
        switch self {
        case .all: nil
        case .inProgress: "in_progress"
        case .completed: "completed"
        }
    }
}

// MARK: - List VM

@MainActor
@Observable
final class DefectListViewModel {
    var items: [DefectListItemDTO] = []
    var meta: PageMetaDTO?
    var isLoading = false
    var errorMessage: String?
    var statusFilter: DefectStatusFilter = .all
    /// 與搜尋框同步（debounce 後寫入）；列表 API 使用 `q`。
    var searchQuery = ""

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load(projectId: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let q = trimmedSearchQuery.isEmpty ? nil : String(trimmedSearchQuery.prefix(200))
            let env = try await APIService.listDefectImprovements(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                status: statusFilter.queryValue,
                q: q
            )
            items = env.data
            meta = env.meta
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func deleteDefect(projectId: String, defectId: String, token: String) async {
        errorMessage = nil
        do {
            try await APIService.deleteDefectImprovement(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                defectId: defectId
            )
            await load(projectId: projectId, token: token)
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - List edit sheet target

private struct DefectEditSheetTarget: Identifiable {
    let id: String
}

// MARK: - Module shell

struct DeficiencyModuleView: View {
    @Environment(SessionManager.self) private var session
    @State private var model = DefectListViewModel()
    @State private var showCreate = false
    @State private var fabScrollIdle = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let pid = session.selectedProjectId, let token = session.accessToken {
                    DefectListView(
                        projectId: pid,
                        accessToken: token,
                        model: model,
                        fabScrollIdle: $fabScrollIdle
                    )
                } else {
                    Text("缺少專案或登入狀態")
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if session.selectedProjectId != nil, session.accessToken != nil {
                Button {
                    showCreate = true
                } label: {
                    ObsidianSquareFAB(accessibilityLabel: "新增缺失紀錄")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, TacticalGlassTheme.fieldFABBottomInset)
                .opacity(fabScrollIdle ? 1 : 0)
                .allowsHitTesting(fabScrollIdle)
                .animation(.easeInOut(duration: 0.2), value: fabScrollIdle)
            }
        }
        .background(TacticalGlassTheme.surface)
        .sheet(isPresented: $showCreate) {
            if let pid = session.selectedProjectId, let token = session.accessToken {
                NavigationStack {
                    DefectCreateView(projectId: pid, accessToken: token) {
                        await model.load(projectId: pid, token: token)
                    }
                }
                .presentationDetents([.large])
            }
        }
    }
}

// MARK: - List

struct DefectListView: View {
    let projectId: String
    let accessToken: String
    @Bindable var model: DefectListViewModel
    @Binding var fabScrollIdle: Bool
    @State private var searchFieldText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var defectIdPendingDelete: String?
    /// 不用 `NavigationLink`，避免 `List` 右側系統 disclosure 箭頭（卡片內已有「詳情」）。
    @State private var navigateToDefectId: String?
    @State private var defectEditSheetTarget: DefectEditSheetTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            obsidianModuleHeader(title: "缺失紀錄")
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            defectSearchField
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            filterPills
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if let err = model.errorMessage {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            if model.isLoading && model.items.isEmpty {
                Spacer()
                ProgressView("載入中…")
                    .tint(TacticalGlassTheme.primary)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if model.items.isEmpty {
                Spacer()
                Text(model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "尚無缺失紀錄" : "查無符合的紀錄")
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(model.items) { item in
                        Button {
                            navigateToDefectId = item.id
                        } label: {
                            defectCard(item)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                defectEditSheetTarget = DefectEditSheetTarget(id: item.id)
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            .tint(TacticalGlassTheme.primary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                defectIdPendingDelete = item.id
                            } label: {
                                Label("刪除", systemImage: "trash.fill")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 8)
                .refreshable {
                    await model.load(projectId: projectId, token: accessToken)
                }
                .fieldFABScrollIdleTracking($fabScrollIdle)
            }
        }
        .navigationDestination(item: $navigateToDefectId) { defectId in
            DefectDetailView(
                projectId: projectId,
                defectId: defectId,
                accessToken: accessToken
            )
        }
        .sheet(item: $defectEditSheetTarget) { target in
            NavigationStack {
                DefectEditView(
                    projectId: projectId,
                    defectId: target.id,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
        .task(id: model.statusFilter) {
            await model.load(projectId: projectId, token: accessToken)
        }
        .onChange(of: searchFieldText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    model.searchQuery = newValue
                }
                await model.load(projectId: projectId, token: accessToken)
            }
        }
        .confirmationDialog(
            "確定刪除此筆缺失紀錄？此動作無法復原。",
            isPresented: Binding(
                get: { defectIdPendingDelete != nil },
                set: { if !$0 { defectIdPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) {
                guard let id = defectIdPendingDelete else { return }
                defectIdPendingDelete = nil
                Task {
                    await model.deleteDefect(projectId: projectId, defectId: id, token: accessToken)
                }
            }
            Button("取消", role: .cancel) {
                defectIdPendingDelete = nil
            }
        }
    }

    private var defectSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
            TextField("搜尋說明、發現人、位置…", text: $searchFieldText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .submitLabel(.search)
            if !searchFieldText.isEmpty {
                Button {
                    searchFieldText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainerHighest.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
        }
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DefectStatusFilter.allCases) { filter in
                    Button {
                        model.statusFilter = filter
                    } label: {
                        Text(filter.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(
                                        model.statusFilter == filter
                                            ? TacticalGlassTheme.primary.opacity(0.22)
                                            : TacticalGlassTheme.surfaceContainerHighest.opacity(0.75)
                                    )
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        model.statusFilter == filter
                                            ? TacticalGlassTheme.primary.opacity(0.55)
                                            : TacticalGlassTheme.ghostBorder,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .foregroundStyle(
                        model.statusFilter == filter
                            ? TacticalGlassTheme.primary
                            : TacticalGlassTheme.mutedLabel
                    )
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func defectCard(_ item: DefectListItemDTO) -> some View {
        let urgent = item.priority == "high" && item.status == "in_progress"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(locationLine(floor: item.floor, location: item.location))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .tracking(0.8)
                Spacer(minLength: 8)
                defectStatusBadge(item.status)
            }

            Text(item.description)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                priorityChip(item.priority)
                Text("發現人：\(item.discoveredBy)")
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }

            if item.status == "in_progress" {
                progressStrip
            }

            if urgent {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TacticalGlassTheme.statusDanger)
                    Text("需緊急關注")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.statusDanger)
                }
                .padding(.top, 2)
            }

            HStack {
                Text("ID \(item.id.prefix(8).uppercased())")
                    .font(.tacticalMonoFixed(size: 11, weight: .medium))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                Spacer()
                Text("詳情")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TacticalGlassTheme.primary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TacticalGlassTheme.primary.opacity(0.8))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(
                    urgent
                        ? TacticalGlassTheme.surfaceContainerHighest
                        : TacticalGlassTheme.surfaceContainer
                )
        }
    }

    private var progressStrip: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(TacticalGlassTheme.surfaceContainerLowest)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(TacticalGlassTheme.primaryGradient())
                    .frame(width: max(0, geo.size.width * 0.42))
            }
        }
        .frame(height: 6)
    }

    private func locationLine(floor: String?, location: String?) -> String {
        let f = floor?.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (f, l) {
        case let (ff?, ll?) where !ff.isEmpty && !ll.isEmpty:
            return "\(ll.uppercased()) · \(ff.uppercased())"
        case let (ff?, _) where !ff.isEmpty:
            return ff.uppercased()
        case let (_, ll?) where !ll.isEmpty:
            return ll.uppercased()
        default:
            return "位置未填"
        }
    }

    private func defectStatusBadge(_ status: String) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case "completed": ("已完成", TacticalGlassTheme.statusSuccess)
            case "in_progress": ("進行中", TacticalGlassTheme.primary)
            default: (status, TacticalGlassTheme.mutedLabel)
            }
        }()
        return Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }

    private func priorityChip(_ priority: String) -> some View {
        let text: String = {
            switch priority {
            case "high": return "高"
            case "low": return "低"
            default: return "中"
            }
        }()
        let color: Color = priority == "high" ? TacticalGlassTheme.statusDanger : TacticalGlassTheme.mutedLabel
        return Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

// MARK: - Detail

@MainActor
@Observable
final class DefectDetailViewModel {
    var defect: DefectDetailDTO?
    var records: [DefectExecutionRecordDTO] = []
    var isLoading = false
    var errorMessage: String?

    func load(projectId: String, defectId: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let d = APIService.getDefectImprovement(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                defectId: defectId
            )
            async let r = APIService.listDefectExecutionRecords(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                defectId: defectId
            )
            defect = try await d
            records = try await r
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private enum DefectDetailPrimaryTab: String, CaseIterable {
    case detail
    case records

    var title: String {
        switch self {
        case .detail: "缺失詳情"
        case .records: "執行紀錄"
        }
    }
}

struct DefectDetailView: View {
    let projectId: String
    let defectId: String
    let accessToken: String

    @State private var model = DefectDetailViewModel()
    @State private var primaryTab: DefectDetailPrimaryTab = .detail
    @State private var showAddRecord = false
    @State private var showEditDefect = false
    @State private var defectRecordToEdit: DefectExecutionRecordDTO?
    @State private var fabScrollIdle = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if let err = model.errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                if model.isLoading && model.defect == nil {
                    Spacer(minLength: 0)
                    ProgressView("載入中…")
                        .tint(TacticalGlassTheme.primary)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                } else if let d = model.defect {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryHeader(d)
                        Picker("區塊", selection: $primaryTab) {
                            ForEach(DefectDetailPrimaryTab.allCases, id: \.self) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(TacticalGlassTheme.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    Group {
                        switch primaryTab {
                        case .detail:
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    detailTabContent(d)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                            }
                            .scrollDismissesKeyboard(.immediately)
                            .fieldFABScrollIdleTracking($fabScrollIdle)
                            .refreshable {
                                await model.load(projectId: projectId, defectId: defectId, token: accessToken)
                            }
                        case .records:
                            defectRecordsList
                                .fieldFABScrollIdleTracking($fabScrollIdle)
                                .refreshable {
                                    await model.load(projectId: projectId, defectId: defectId, token: accessToken)
                                }
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }

            if primaryTab == .records, model.defect != nil {
                Button {
                    showAddRecord = true
                } label: {
                    ObsidianSquareFAB(accessibilityLabel: "新增執行紀錄")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, TacticalGlassTheme.fieldFABBottomInset)
                .opacity(fabScrollIdle ? 1 : 0)
                .allowsHitTesting(fabScrollIdle)
                .animation(.easeInOut(duration: 0.2), value: fabScrollIdle)
            }
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("缺失詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if primaryTab == .detail, model.defect != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("編輯") { showEditDefect = true }
                        .foregroundStyle(TacticalGlassTheme.primary)
                }
            }
        }
        .task {
            await model.load(projectId: projectId, defectId: defectId, token: accessToken)
        }
        .onChange(of: primaryTab) { _, _ in
            fabScrollIdle = true
        }
        .sheet(isPresented: $showAddRecord) {
            NavigationStack {
                DefectRecordCreateView(
                    projectId: projectId,
                    defectId: defectId,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, defectId: defectId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showEditDefect) {
            NavigationStack {
                DefectEditView(
                    projectId: projectId,
                    defectId: defectId,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, defectId: defectId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $defectRecordToEdit) { rec in
            NavigationStack {
                DefectRecordEditView(
                    projectId: projectId,
                    defectId: defectId,
                    record: rec,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, defectId: defectId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
    }

    private var defectRecordsList: some View {
        Group {
            if model.records.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("尚無紀錄")
                            .font(.subheadline)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        Text("點右下角 ＋ 新增執行紀錄（可附照片）。")
                            .font(.footnote)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.immediately)
            } else {
                List {
                    ForEach(model.records) { rec in
                        defectRecordCard(rec)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    defectRecordToEdit = rec
                                } label: {
                                    Label("編輯", systemImage: "pencil")
                                }
                                .tint(TacticalGlassTheme.primary)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 8)
            }
        }
    }

    private func summaryHeader(_ d: DefectDetailDTO) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("#\(d.id.prefix(8).uppercased())")
                    .font(.tacticalMonoFixed(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(defectStatusText(d.status))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            d.status == "completed"
                                ? TacticalGlassTheme.statusSuccess.opacity(0.2)
                                : TacticalGlassTheme.primary.opacity(0.2)
                        )
                    )
                    .foregroundStyle(
                        d.status == "completed"
                            ? TacticalGlassTheme.statusSuccess
                            : TacticalGlassTheme.primary
                    )
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func detailTabContent(_ d: DefectDetailDTO) -> some View {
        TacticalGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                labeled("優先度", value: priorityText(d.priority))
                labeled("發現人", value: d.discoveredBy)
                labeled("樓層", value: d.floor ?? "—")
                labeled("位置", value: d.location ?? "—")
                labeled("建立", value: d.createdAt.formattedAsAppDateTime, mono: true)
                labeled("更新", value: d.updatedAt.formattedAsAppDateTime, mono: true)
            }
        }

        TacticalGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("問題說明")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .tracking(1)
                Text(d.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(4)
            }
        }

        defectPhotosSection(photos: d.photos ?? [])
    }

    /// 永遠顯示「現場照片」區塊；無照片時給空狀態（先前 `photos` 為空會整段不渲染，看起來像沒有照片集）。
    @ViewBuilder
    private func defectPhotosSection(photos: [FileAttachmentDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現場照片")
                .font(.caption.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1)

            if photos.isEmpty {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.65))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("尚未上傳照片")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        Text("建立缺失時可於「現場照片」上傳；若已在網頁版加入，請下拉重新整理。")
                            .font(.caption)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .fill(TacticalGlassTheme.surfaceContainerLowest.opacity(0.65))
                }
            } else {
                TacticalPhotoAlbumGrid(photos: photos, accessToken: accessToken, columnCount: 3, spacing: 10)
            }
        }
    }

    private func defectStatusText(_ status: String) -> String {
        switch status {
        case "completed": "已完成"
        case "in_progress": "進行中"
        default: status
        }
    }

    private func priorityText(_ p: String) -> String {
        switch p {
        case "high": return "高"
        case "low": return "低"
        default: return "中"
        }
    }

    private func labeled(_ title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(0.6)
            if mono {
                Text(value)
                    .font(.tacticalMonoFixed(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private func defectRecordCard(_ rec: DefectExecutionRecordDTO) -> some View {
        TacticalGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let by = rec.recordedBy {
                        Text(by.name ?? by.email)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(rec.createdAt.formattedAsAppDateTime)
                        .font(.tacticalMonoFixed(size: 11, weight: .medium))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                }
                Text(rec.content)
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)

                let pics = rec.photos ?? []
                if !pics.isEmpty {
                    TacticalPhotoAlbumGrid(photos: pics, accessToken: accessToken, columnCount: 3, spacing: 8)
                }
            }
        }
    }
}

// MARK: - Execution record create

@MainActor
@Observable
final class DefectRecordCreateViewModel {
    var contentText = ""
    var photoPickerItems: [PhotosPickerItem] = []
    /// 由 `PhotoPickerPreviewLoader` 從 `photoPickerItems` 解出，供表單預覽。
    var photoPreviewImages: [UIImage] = []
    var isSubmitting = false
    var errorMessage: String?

    var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    var remainingPhotoSlots: Int {
        max(0, 30 - photoPickerItems.count)
    }

    func refreshPhotoPreviews() async {
        photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
    }

    func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task { await refreshPhotoPreviews() }
    }

    func submit(projectId: String, defectId: String, token: String) async -> Bool {
        errorMessage = nil
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "請填寫執行紀錄內容"
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            var attachmentIds: [String] = []
            for item in photoPickerItems {
                guard attachmentIds.count < 30 else { break }
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "record.\(ext)"
                let mime = mimeForImage(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "defect_record"
                )
                attachmentIds.append(up.id)
            }
            guard attachmentIds.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return false
            }

            let body = CreateDefectExecutionRecordBody(content: text, attachmentIds: attachmentIds)
            _ = try await APIService.createDefectExecutionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                defectId: defectId,
                body: body
            )
            return true
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
            return false
        } catch {
            guard !error.isIgnorableTaskCancellation else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func mimeForImage(data: Data, fallbackExtension: String) -> String {
        if fallbackExtension.lowercased() == "png" { return "image/png" }
        if fallbackExtension.lowercased() == "heic" || fallbackExtension.lowercased() == "heif" {
            return "image/heic"
        }
        if data.count >= 2, data[0] == 0xFF, data[1] == 0xD8 { return "image/jpeg" }
        if data.count >= 8, data[0] == 0x89, data[1] == 0x50 { return "image/png" }
        return "image/jpeg"
    }
}

struct DefectRecordCreateView: View {
    let projectId: String
    let defectId: String
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var createModel = DefectRecordCreateViewModel()

    var body: some View {
        @Bindable var model = createModel

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let err = model.errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("執行紀錄內容".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(1.2)
                            TextField("", text: $model.contentText, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(6 ... 14)
                                .textInputAutocapitalization(.sentences)
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.28))
                                .frame(height: 1)
                        }
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("照片（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .tracking(0.8)
                        FieldFormPhotoStrip(
                            accessToken: accessToken,
                            remotePhotoIds: [],
                            localPreviewImages: model.photoPreviewImages,
                            onRemoveRemote: { _ in },
                            onRemoveLocal: { index in model.removePhotoPickerItem(at: index) }
                        )
                        if model.remainingPhotoSlots > 0 {
                            PhotosPicker(
                                selection: $model.photoPickerItems,
                                maxSelectionCount: min(12, model.remainingPhotoSlots),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("從相簿新增", systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            }
                        } else {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(model.photoPickerItems.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    Task {
                        let ok = await createModel.submit(projectId: projectId, defectId: defectId, token: accessToken)
                        if ok {
                            await onFinished()
                            dismiss()
                        }
                    }
                } label: {
                    if createModel.isSubmitting {
                        ProgressView()
                            .tint(TacticalGlassTheme.onPrimary)
                    } else {
                        Text("送出紀錄")
                    }
                }
                .buttonStyle(TacticalPrimaryButtonStyle())
                .disabled(createModel.isSubmitting)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
        .onChange(of: model.photoPickerFingerprint) { _, _ in
            Task { await model.refreshPhotoPreviews() }
        }
        .navigationTitle("新增執行紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
    }
}

// MARK: - Edit defect (main)

@MainActor
@Observable
final class DefectEditViewModel {
    var descriptionText = ""
    var discoveredBy = ""
    var priority: String = "medium"
    var floor = ""
    var location = ""
    var status: String = "in_progress"
    var committedPhotoIds: [String] = []
    var photoPickerItems: [PhotosPickerItem] = []
    var photoPreviewImages: [UIImage] = []
    var isSaving = false
    var errorMessage: String?

    var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    var remainingPhotoSlots: Int {
        max(0, 30 - committedPhotoIds.count - photoPickerItems.count)
    }

    func refreshPhotoPreviews() async {
        photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
    }

    func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task { await refreshPhotoPreviews() }
    }

    func load(defect: DefectDetailDTO) {
        descriptionText = defect.description
        discoveredBy = defect.discoveredBy
        priority = defect.priority
        floor = defect.floor ?? ""
        location = defect.location ?? ""
        status = defect.status
        committedPhotoIds = defect.photos?.map(\.id) ?? []
        photoPickerItems = []
        photoPreviewImages = []
    }

    func save(projectId: String, defectId: String, token: String) async -> Bool {
        errorMessage = nil
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let by = discoveredBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else {
            errorMessage = "請填寫問題說明"
            return false
        }
        guard !by.isEmpty else {
            errorMessage = "請填寫發現人"
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            var newIds: [String] = []
            for item in photoPickerItems {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "defect.\(ext)"
                let mime = defectMimeForImageData(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "defect"
                )
                newIds.append(up.id)
            }
            let merged = defectUniqIdsPreservingOrder(committedPhotoIds + newIds)
            guard merged.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return false
            }

            let body = UpdateDefectImprovementBody(
                description: desc,
                discoveredBy: by,
                priority: priority,
                floor: floor.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                status: status,
                attachmentIds: merged
            )

            _ = try await APIService.updateDefectImprovement(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                defectId: defectId,
                body: body
            )
            return true
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
            return false
        } catch {
            guard !error.isIgnorableTaskCancellation else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct DefectEditView: View {
    let projectId: String
    let defectId: String
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm = DefectEditViewModel()

    var body: some View {
        @Bindable var edit = vm

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("問題說明".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            TextField("", text: $edit.descriptionText, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(4 ... 12)
                                .textInputAutocapitalization(.sentences)
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.25))
                                .frame(height: 1)
                        }

                        TacticalTextField(title: "發現人", text: $edit.discoveredBy, contentType: .name)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("優先度".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            Picker("", selection: $edit.priority) {
                                Text("低").tag("low")
                                Text("中").tag("medium")
                                Text("高").tag("high")
                            }
                            .pickerStyle(.segmented)
                            .tint(TacticalGlassTheme.primary)
                        }

                        TacticalTextField(title: "樓層（選填）", text: $edit.floor)
                        TacticalTextField(title: "位置（選填）", text: $edit.location)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("狀態".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            Picker("", selection: $edit.status) {
                                Text("進行中").tag("in_progress")
                                Text("已完成").tag("completed")
                            }
                            .pickerStyle(.segmented)
                            .tint(TacticalGlassTheme.primary)
                        }
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("現場照片（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        FieldFormPhotoStrip(
                            accessToken: accessToken,
                            remotePhotoIds: edit.committedPhotoIds,
                            localPreviewImages: edit.photoPreviewImages,
                            onRemoveRemote: { id in edit.committedPhotoIds.removeAll { $0 == id } },
                            onRemoveLocal: { index in edit.removePhotoPickerItem(at: index) }
                        )
                        if edit.remainingPhotoSlots > 0 {
                            PhotosPicker(
                                selection: $edit.photoPickerItems,
                                maxSelectionCount: min(12, edit.remainingPhotoSlots),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("從相簿新增", systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            }
                        } else {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(edit.committedPhotoIds.count + edit.photoPickerItems.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    Task {
                        let ok = await vm.save(projectId: projectId, defectId: defectId, token: accessToken)
                        if ok {
                            await onFinished()
                            dismiss()
                        }
                    }
                } label: {
                    if vm.isSaving {
                        ProgressView()
                            .tint(TacticalGlassTheme.onPrimary)
                    } else {
                        Text("儲存變更")
                    }
                }
                .buttonStyle(TacticalPrimaryButtonStyle())
                .disabled(vm.isSaving)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
        .onChange(of: edit.photoPickerFingerprint) { _, _ in
            Task { await edit.refreshPhotoPreviews() }
        }
        .navigationTitle("編輯缺失")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
        .task {
            do {
                let d = try await APIService.getDefectImprovement(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    defectId: defectId
                )
                vm.load(defect: d)
            } catch let api as APIRequestError {
                vm.errorMessage = api.localizedDescription
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }
}

struct DefectRecordEditView: View {
    let projectId: String
    let defectId: String
    let record: DefectExecutionRecordDTO
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentText = ""
    @State private var committedPhotoIds: [String] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var photoPreviewImages: [UIImage] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    private var remainingPhotoSlots: Int {
        max(0, 30 - committedPhotoIds.count - photoPickerItems.count)
    }

    private func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task {
            photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let err = errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("執行紀錄內容".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            TextField("", text: $contentText, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(6 ... 18)
                                .textInputAutocapitalization(.sentences)
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.28))
                                .frame(height: 1)
                        }
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("照片（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        FieldFormPhotoStrip(
                            accessToken: accessToken,
                            remotePhotoIds: committedPhotoIds,
                            localPreviewImages: photoPreviewImages,
                            onRemoveRemote: { id in committedPhotoIds.removeAll { $0 == id } },
                            onRemoveLocal: { index in removePhotoPickerItem(at: index) }
                        )
                        if remainingPhotoSlots > 0 {
                            PhotosPicker(
                                selection: $photoPickerItems,
                                maxSelectionCount: min(12, remainingPhotoSlots),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("從相簿新增", systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            }
                        } else {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(committedPhotoIds.count + photoPickerItems.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(TacticalGlassTheme.onPrimary)
                    } else {
                        Text("儲存")
                    }
                }
                .buttonStyle(TacticalPrimaryButtonStyle())
                .disabled(isSaving)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
        .onAppear {
            contentText = record.content
            committedPhotoIds = record.photos?.map(\.id) ?? []
        }
        .onChange(of: photoPickerFingerprint) { _, _ in
            Task {
                photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
            }
        }
        .navigationTitle("編輯執行紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
    }

    private func save() async {
        errorMessage = nil
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "請填寫內容"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            var newIds: [String] = []
            for item in photoPickerItems {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "record.\(ext)"
                let mime = defectMimeForImageData(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "defect_record"
                )
                newIds.append(up.id)
            }
            let merged = defectUniqIdsPreservingOrder(committedPhotoIds + newIds)
            guard merged.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return
            }
            _ = try await APIService.updateDefectExecutionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                defectId: defectId,
                recordId: record.id,
                body: UpdateDefectExecutionRecordBody(content: text, attachmentIds: merged)
            )
            await onFinished()
            dismiss()
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Create

@MainActor
@Observable
final class DefectCreateViewModel {
    var descriptionText = ""
    var discoveredBy = ""
    var priority: String = "medium"
    var floor = ""
    var location = ""
    var status: String = "in_progress"
    var photoPickerItems: [PhotosPickerItem] = []
    var photoPreviewImages: [UIImage] = []
    var isSubmitting = false
    var errorMessage: String?

    var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    var remainingPhotoSlots: Int {
        max(0, 30 - photoPickerItems.count)
    }

    func refreshPhotoPreviews() async {
        photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
    }

    func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task { await refreshPhotoPreviews() }
    }

    func submit(projectId: String, token: String) async -> Bool {
        errorMessage = nil
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let by = discoveredBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else {
            errorMessage = "請填寫問題說明"
            return false
        }
        guard !by.isEmpty else {
            errorMessage = "請填寫發現人"
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            var attachmentIds: [String] = []
            for item in photoPickerItems {
                guard attachmentIds.count < 30 else { break }
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "defect.\(ext)"
                let mime = mimeForImage(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "defect"
                )
                attachmentIds.append(up.id)
            }
            guard attachmentIds.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return false
            }

            let body = CreateDefectImprovementBody(
                description: desc,
                discoveredBy: by,
                priority: priority,
                floor: floor.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                status: status,
                attachmentIds: attachmentIds
            )

            _ = try await APIService.createDefectImprovement(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                body: body
            )
            return true
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
            return false
        } catch {
            guard !error.isIgnorableTaskCancellation else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func mimeForImage(data: Data, fallbackExtension: String) -> String {
        if fallbackExtension.lowercased() == "png" { return "image/png" }
        if fallbackExtension.lowercased() == "heic" || fallbackExtension.lowercased() == "heif" {
            return "image/heic"
        }
        if data.count >= 2, data[0] == 0xFF, data[1] == 0xD8 { return "image/jpeg" }
        if data.count >= 8, data[0] == 0x89, data[1] == 0x50 { return "image/png" }
        return "image/jpeg"
    }
}

struct DefectCreateView: View {
    let projectId: String
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var createModel = DefectCreateViewModel()

    var body: some View {
        @Bindable var vm = createModel

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("問題說明".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(1.2)
                            TextField("", text: $vm.descriptionText, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(4 ... 10)
                                .textInputAutocapitalization(.sentences)
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.25))
                                .frame(height: 1)
                        }

                        TacticalTextField(title: "發現人", text: $vm.discoveredBy, contentType: .name)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("優先度".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(1.2)
                            Picker("", selection: $vm.priority) {
                                Text("低").tag("low")
                                Text("中").tag("medium")
                                Text("高").tag("high")
                            }
                            .pickerStyle(.segmented)
                            .tint(TacticalGlassTheme.primary)
                        }

                        TacticalTextField(title: "樓層（選填）", text: $vm.floor)
                        TacticalTextField(title: "位置（選填）", text: $vm.location)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("狀態".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(1.2)
                            Picker("", selection: $vm.status) {
                                Text("進行中").tag("in_progress")
                                Text("已完成").tag("completed")
                            }
                            .pickerStyle(.segmented)
                            .tint(TacticalGlassTheme.primary)
                        }
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("現場照片（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .tracking(0.8)
                        FieldFormPhotoStrip(
                            accessToken: accessToken,
                            remotePhotoIds: [],
                            localPreviewImages: vm.photoPreviewImages,
                            onRemoveRemote: { _ in },
                            onRemoveLocal: { index in vm.removePhotoPickerItem(at: index) }
                        )
                        if vm.remainingPhotoSlots > 0 {
                            PhotosPicker(
                                selection: $vm.photoPickerItems,
                                maxSelectionCount: min(12, vm.remainingPhotoSlots),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("從相簿新增", systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            }
                        } else {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(vm.photoPickerItems.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    Task {
                        let ok = await createModel.submit(projectId: projectId, token: accessToken)
                        if ok {
                            dismiss()
                            await onFinished()
                        }
                    }
                } label: {
                    if createModel.isSubmitting {
                        ProgressView()
                            .tint(TacticalGlassTheme.onPrimary)
                    } else {
                        Text("送出")
                    }
                }
                .buttonStyle(TacticalPrimaryButtonStyle())
                .disabled(createModel.isSubmitting)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(TacticalGlassTheme.surface)
        .onChange(of: vm.photoPickerFingerprint) { _, _ in
            Task { await vm.refreshPhotoPreviews() }
        }
        .navigationTitle("新增紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
    }
}

// MARK: - Shared header (SITE_OPS-style)

func obsidianModuleHeader(title: String) -> some View {
    Text(title)
        .tacticalTitle(28, weight: .bold)
        .foregroundStyle(.white)
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
