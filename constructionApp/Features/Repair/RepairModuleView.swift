//
//  RepairModuleView.swift
//  constructionApp
//

import Combine
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private func repairUniqIdsPreservingOrder(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    out.reserveCapacity(ids.count)
    for id in ids where seen.insert(id).inserted {
        out.append(id)
    }
    return out
}

private func repairMimeForImageData(data: Data, fallbackExtension: String) -> String {
    if fallbackExtension.lowercased() == "png" { return "image/png" }
    if fallbackExtension.lowercased() == "heic" || fallbackExtension.lowercased() == "heif" {
        return "image/heic"
    }
    if data.count >= 2, data[0] == 0xFF, data[1] == 0xD8 { return "image/jpeg" }
    if data.count >= 8, data[0] == 0x89, data[1] == 0x50 { return "image/png" }
    return "image/jpeg"
}

private func repairMimeTypeForFileURL(_ url: URL) -> String {
    if let type = UTType(filenameExtension: url.pathExtension),
       let mime = type.preferredMIMEType {
        return mime
    }
    return "application/octet-stream"
}

// MARK: - List

enum RepairStatusFilter: String, CaseIterable, Identifiable {
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

@MainActor
@Observable
final class RepairListViewModel {
    var items: [RepairListItemDTO] = []
    var meta: PageMetaDTO?
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var statusFilter: RepairStatusFilter = .all
    var searchQuery = ""

    var hasMore: Bool {
        guard let meta else { return false }
        return items.count < meta.total
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load(projectId: String, session: SessionManager) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let q = trimmedSearchQuery.isEmpty ? nil : String(trimmedSearchQuery.prefix(200))
            let status = statusFilter.queryValue
            let env = try await session.withValidAccessToken { token in
                try await APIService.listRepairRequests(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    status: status,
                    q: q,
                    page: 1,
                    limit: FieldListPagination.pageSize
                )
            }
            items = env.data
            meta = env.meta
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(projectId: String, session: SessionManager) async {
        guard let m = meta, hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = m.page + 1
        do {
            let q = trimmedSearchQuery.isEmpty ? nil : String(trimmedSearchQuery.prefix(200))
            let status = statusFilter.queryValue
            let env = try await session.withValidAccessToken { token in
                try await APIService.listRepairRequests(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    status: status,
                    q: q,
                    page: nextPage,
                    limit: FieldListPagination.pageSize
                )
            }
            let existing = Set(items.map(\.id))
            let newRows = env.data.filter { !existing.contains($0.id) }
            items.append(contentsOf: newRows)
            meta = env.meta
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func deleteRepair(projectId: String, repairId: String, session: SessionManager) async {
        errorMessage = nil
        do {
            try await session.withValidAccessToken { token in
                try await APIService.deleteRepairRequest(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    repairId: repairId
                )
            }
            await load(projectId: projectId, session: session)
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct RepairHomeView: View {
    @Environment(SessionManager.self) private var session
    @State private var model = RepairListViewModel()
    @State private var fabScrollIdle = true

    var body: some View {
        Group {
            if let pid = session.selectedProjectId, session.isAuthenticated {
                RepairRequestsListView(
                    projectId: pid,
                    model: model,
                    fabScrollIdle: $fabScrollIdle
                )
            } else {
                Text("缺少專案或登入狀態")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TacticalGlassTheme.surface)
    }
}

private struct RepairEditSheetTarget: Identifiable {
    let id: String
}

private struct PendingRepairParentTarget: Identifiable {
    let id: UUID
}

struct RepairRequestsListView: View {
    enum ListChrome {
        case main
        case searchSession
    }

    let projectId: String
    @Bindable var model: RepairListViewModel
    @Binding var fabScrollIdle: Bool
    var listChrome: ListChrome = .main

    @Environment(FieldOutboxStore.self) private var outbox
    @Environment(SessionManager.self) private var session

    @State private var searchSessionPresented = false
    @State private var showCreateRepair = false
    @State private var searchFieldText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool
    @State private var repairIdPendingDelete: String?
    @State private var navigateToRepairId: String?
    @State private var repairEditSheetTarget: RepairEditSheetTarget?
    @State private var pendingRecordSheetParent: PendingRepairParentTarget?

    private var pendingRepairs: [FieldOutboxIndexRecord] {
        outbox.records(forProjectId: projectId).filter { $0.kind == .repairCreate }
    }

    private var showEmptyPlaceholder: Bool {
        model.items.isEmpty && pendingRepairs.isEmpty
    }

    private var listBottomContentMargin: CGFloat {
        listChrome == .searchSession ? 28 : TacticalGlassTheme.tabBarScrollBottomMargin
    }

    var body: some View {
        Group {
            if listChrome == .main {
                mainChromeStack
                    .navigationDestination(isPresented: $searchSessionPresented) {
                        RepairListSearchSessionView(
                            projectId: projectId,
                            model: model,
                            fabScrollIdle: $fabScrollIdle
                        )
                    }
            } else {
                searchSessionChromeStack
            }
        }
        .navigationDestination(item: $navigateToRepairId) { repairId in
            RepairRequestDetailView(
                projectId: projectId,
                repairId: repairId,
                accessToken: session.accessToken ?? ""
            )
        }
        .sheet(item: $repairEditSheetTarget) { target in
            NavigationStack {
                RepairEditView(
                    projectId: projectId,
                    repairId: target.id,
                    accessToken: session.accessToken ?? ""
                ) {
                    await model.load(projectId: projectId, session: session)
                }
            }
            .presentationDetents([.large])
        }
        .task(id: model.statusFilter) {
            await model.load(projectId: projectId, session: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldRemoteDataShouldRefresh)) { _ in
            Task {
                await model.load(projectId: projectId, session: session)
            }
        }
        .onChange(of: searchFieldText) { _, newValue in
            guard listChrome == .searchSession else { return }
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    model.searchQuery = newValue
                }
                await model.load(projectId: projectId, session: session)
            }
        }
        .onAppear {
            guard listChrome == .searchSession else { return }
            searchFieldText = model.searchQuery
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                searchFieldFocused = true
            }
        }
        .confirmationDialog(
            "確定刪除此筆報修？此動作無法復原。",
            isPresented: Binding(
                get: { repairIdPendingDelete != nil },
                set: { if !$0 { repairIdPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) {
                guard let id = repairIdPendingDelete else { return }
                repairIdPendingDelete = nil
                Task {
                    await model.deleteRepair(projectId: projectId, repairId: id, session: session)
                }
            }
            Button("取消", role: .cancel) {
                repairIdPendingDelete = nil
            }
        }
        .sheet(item: $pendingRecordSheetParent) { target in
            NavigationStack {
                RepairRecordCreateView(
                    projectId: projectId,
                    pendingRepairOutboxParentId: target.id,
                    accessToken: session.accessToken ?? ""
                ) {
                    await model.load(projectId: projectId, session: session)
                }
            }
            .presentationDetents([.large])
        }
    }

    private var mainChromeStack: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                obsidianModuleHeader(title: "報修紀錄")
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Button {
                    searchSessionPresented = true
                } label: {
                    ObsidianListSearchPillAffordance(
                        placeholder: "搜尋客戶、電話、內容、類別…",
                        activeQuerySummary: model.searchQuery
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                filterBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                resultsBlock
            }

            Button {
                showCreateRepair = true
            } label: {
                ObsidianSquareFAB(accessibilityLabel: "新增報修")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, TacticalGlassTheme.fieldFABBottomInset)
            .opacity(fabScrollIdle ? 1 : 0)
            .allowsHitTesting(fabScrollIdle)
            .animation(.easeInOut(duration: 0.2), value: fabScrollIdle)
        }
        .sheet(isPresented: $showCreateRepair) {
            if let token = session.accessToken {
                NavigationStack {
                    RepairCreateView(projectId: projectId, accessToken: token) {
                        await model.load(projectId: projectId, session: session)
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private var searchSessionChromeStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            ObsidianSearchModePillField(
                text: $searchFieldText,
                placeholder: "搜尋客戶、電話、內容、類別…",
                isFocused: $searchFieldFocused
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)

            filterBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            resultsBlock
        }
    }

    @ViewBuilder
    private var resultsBlock: some View {
        if let err = model.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                    Text("無法載入列表")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Text(err)
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Button("重試") {
                    Task { await model.load(projectId: projectId, session: session) }
                }
                .buttonStyle(TacticalSecondaryButtonStyle())
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.surfaceContainer.opacity(0.95))
            }
            .overlay {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .strokeBorder(TacticalGlassTheme.tertiary.opacity(0.35), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        } else if model.isLoading && showEmptyPlaceholder {
            Spacer()
            ProgressView("載入中…")
                .tint(TacticalGlassTheme.primary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Spacer()
        } else if showEmptyPlaceholder {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                Text(model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "尚無報修資料" : "查無符合的紀錄")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            Spacer()
        } else {
            List {
                ForEach(pendingRepairs) { rec in
                    repairPendingOutboxRow(rec)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                ForEach(model.items) { item in
                    Button {
                        navigateToRepairId = item.id
                    } label: {
                        repairRow(item)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            repairEditSheetTarget = RepairEditSheetTarget(id: item.id)
                        } label: {
                            Label("編輯", systemImage: "pencil")
                        }
                        .tint(TacticalGlassTheme.primary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            repairIdPendingDelete = item.id
                        } label: {
                            Label("刪除", systemImage: "trash.fill")
                        }
                    }
                }
                if model.hasMore {
                    Button {
                        Task { await model.loadMore(projectId: projectId, session: session) }
                    } label: {
                        HStack {
                            if model.isLoadingMore {
                                ProgressView()
                                    .tint(TacticalGlassTheme.primary)
                            }
                            Text(model.isLoadingMore ? "載入中…" : "載入更多")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TacticalGlassTheme.primary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .disabled(model.isLoadingMore)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, listBottomContentMargin, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.defaultMinListRowHeight, 8)
            .refreshable {
                await model.load(projectId: projectId, session: session)
            }
            .fieldFABScrollIdleTracking($fabScrollIdle)
        }
    }

    private func repairPendingOutboxRow(_ rec: FieldOutboxIndexRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(rec.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text("待上傳")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(TacticalGlassTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TacticalGlassTheme.primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text("連線後將建立於伺服器；可先新增執行紀錄並一併上傳。")
                .font(.caption)
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                pendingRecordSheetParent = PendingRepairParentTarget(id: rec.id)
            } label: {
                Text("新增執行紀錄")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TacticalSecondaryButtonStyle())
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainer.opacity(0.95))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.primary.opacity(0.25), lineWidth: 1)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RepairStatusFilter.allCases) { filter in
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

    private func repairRow(_ item: RepairListItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.customerName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                statusBadge(item.status)
            }

            Text(item.repairContent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 12) {
                Label(item.problemCategory, systemImage: "tag")
                    .font(.caption)
                    .foregroundStyle(TacticalGlassTheme.primary.opacity(0.9))
                if item.isSecondRepair {
                    Text("二次報修")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(TacticalGlassTheme.tertiary.opacity(0.15)))
                }
            }

            Text(item.updatedAt.formattedAsAppDateTime)
                .font(.tacticalMonoFixed(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainer)
        }
    }

    private func statusBadge(_ status: String) -> some View {
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
}

private struct RepairListSearchSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let projectId: String
    @Bindable var model: RepairListViewModel
    @Binding var fabScrollIdle: Bool

    var body: some View {
        RepairRequestsListView(
            projectId: projectId,
            model: model,
            fabScrollIdle: $fabScrollIdle,
            listChrome: .searchSession
        )
        .navigationBarBackButtonHidden(true)
        .navigationTitle("搜尋報修")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
                .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
    }
}

// MARK: - Detail

@MainActor
@Observable
final class RepairDetailViewModel {
    var repair: RepairDetailDTO?
    var records: [RepairExecutionRecordDTO] = []
    var isLoading = false
    var errorMessage: String?

    func load(projectId: String, repairId: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let r = APIService.getRepairRequest(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                repairId: repairId
            )
            async let rec = APIService.listRepairExecutionRecords(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                repairId: repairId
            )
            repair = try await r
            records = try await rec
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private enum RepairDetailPrimaryTab: String, CaseIterable {
    case detail
    case records

    var title: String {
        switch self {
        case .detail: "報修詳情"
        case .records: "報修紀錄"
        }
    }
}

struct RepairRequestDetailView: View {
    let projectId: String
    let repairId: String
    let accessToken: String

    @State private var model = RepairDetailViewModel()
    @State private var primaryTab: RepairDetailPrimaryTab = .detail
    @State private var showAddRecord = false
    @State private var showEditRepair = false
    @State private var fabScrollIdle = true
    @State private var recordToEdit: RepairExecutionRecordDTO?

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

                if model.isLoading && model.repair == nil {
                    Spacer(minLength: 0)
                    ProgressView("載入中…")
                        .tint(TacticalGlassTheme.primary)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                } else if let r = model.repair {
                    VStack(alignment: .leading, spacing: 12) {
                        repairSummaryHeader(r)
                        Picker("區塊", selection: $primaryTab) {
                            ForEach(RepairDetailPrimaryTab.allCases, id: \.self) { tab in
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
                                    repairDetailTabCards(r)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                            }
                            .scrollDismissesKeyboard(.immediately)
                            .fieldFABScrollIdleTracking($fabScrollIdle)
                            .refreshable {
                                await model.load(projectId: projectId, repairId: repairId, token: accessToken)
                            }
                        case .records:
                            repairRecordsList
                                .fieldFABScrollIdleTracking($fabScrollIdle)
                                .refreshable {
                                    await model.load(projectId: projectId, repairId: repairId, token: accessToken)
                                }
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }

            if primaryTab == .records, model.repair != nil {
                Button {
                    showAddRecord = true
                } label: {
                    ObsidianSquareFAB(accessibilityLabel: "新增報修紀錄")
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
        .navigationTitle("報修詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if primaryTab == .detail, model.repair != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("編輯") { showEditRepair = true }
                        .foregroundStyle(TacticalGlassTheme.primary)
                }
            }
        }
        .task {
            await model.load(projectId: projectId, repairId: repairId, token: accessToken)
        }
        .onChange(of: primaryTab) { _, _ in
            fabScrollIdle = true
        }
        .sheet(isPresented: $showAddRecord) {
            NavigationStack {
                RepairRecordCreateView(
                    projectId: projectId,
                    repairId: repairId,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, repairId: repairId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showEditRepair) {
            NavigationStack {
                RepairEditView(
                    projectId: projectId,
                    repairId: repairId,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, repairId: repairId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $recordToEdit) { rec in
            NavigationStack {
                RepairRecordEditView(
                    projectId: projectId,
                    repairId: repairId,
                    record: rec,
                    accessToken: accessToken
                ) {
                    await model.load(projectId: projectId, repairId: repairId, token: accessToken)
                }
            }
            .presentationDetents([.large])
        }
    }

    private var repairRecordsList: some View {
        Group {
            if model.records.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("尚無紀錄")
                            .font(.subheadline)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        Text("點右下角 ＋ 新增報修紀錄（可附照片）。")
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
                        repairRecordRow(rec)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    recordToEdit = rec
                                } label: {
                                    Label("編輯", systemImage: "pencil")
                                }
                                .tint(TacticalGlassTheme.primary)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, TacticalGlassTheme.tabBarScrollBottomMargin, for: .scrollContent)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.defaultMinListRowHeight, 8)
            }
        }
    }

    private func repairSummaryHeader(_ r: RepairDetailDTO) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("#\(r.id.prefix(8).uppercased())")
                    .font(.tacticalMonoFixed(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(repairStatusText(r.status))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            r.status == "completed"
                                ? TacticalGlassTheme.statusSuccess.opacity(0.2)
                                : TacticalGlassTheme.primary.opacity(0.2)
                        )
                    )
                    .foregroundStyle(
                        r.status == "completed"
                            ? TacticalGlassTheme.statusSuccess
                            : TacticalGlassTheme.primary
                    )
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func repairDetailTabCards(_ r: RepairDetailDTO) -> some View {
        TacticalGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                labeled("狀態", value: repairStatusText(r.status))
                labeled("客戶", value: r.customerName)
                labeled("電話", value: r.contactPhone, mono: true)
                labeled("戶別", value: r.unitLabel ?? "—")
                labeled("問題類別", value: r.problemCategory)
                if r.isSecondRepair {
                    Text("二次報修")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }
                labeled("交屋日", value: r.deliveryDate ?? "—", mono: true)
                labeled("修繕完成日", value: r.repairDate ?? "—", mono: true)
                labeled("建立時間", value: r.createdAt.formattedAsAppDateTime, mono: true)
                labeled("更新時間", value: r.updatedAt.formattedAsAppDateTime, mono: true)
            }
        }

        TacticalGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("報修內容")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .tracking(0.8)
                Text(r.repairContent)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }

        if let remarks = r.remarks, !remarks.isEmpty {
            TacticalGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("備註")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    Text(remarks)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        let photos = r.photos ?? []
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("照片")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .padding(.horizontal, 4)
                TacticalPhotoAlbumGrid(photos: photos, columnCount: 3, spacing: 10)
                    .padding(.horizontal, 4)
            }
        }

        let attachments = r.attachments ?? []
        if !attachments.isEmpty {
            TacticalGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("附件")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    ForEach(attachments) { a in
                        Text(a.fileName)
                            .font(.tacticalMonoFixed(size: 12, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func repairRecordRow(_ rec: RepairExecutionRecordDTO) -> some View {
        TacticalGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let by = rec.recordedBy {
                        Text(by.name ?? by.email)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text(rec.createdAt.formattedAsAppDateTime)
                        .font(.tacticalMonoFixed(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Text(rec.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                let pics = rec.photos ?? []
                if !pics.isEmpty {
                    TacticalPhotoAlbumGrid(photos: pics, columnCount: 3, spacing: 8)
                }
            }
        }
    }

    private func repairStatusText(_ status: String) -> String {
        switch status {
        case "completed": "已完成"
        case "in_progress": "進行中"
        default: status
        }
    }

    private func labeled(_ title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            if mono {
                Text(value)
                    .font(.tacticalMonoFixed(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Edit repair (main ticket)

@MainActor
@Observable
final class RepairEditViewModel {
    var customerName = ""
    var contactPhone = ""
    var repairContent = ""
    var unitLabel = ""
    var remarks = ""
    var problemCategory = ""
    var isSecondRepair = false
    var status: String = "in_progress"
    var deliveryDateYMD = ""
    var repairDateYMD = ""
    var committedPhotoIds: [String] = []
    var committedFileAttachments: [(id: String, fileName: String)] = []
    var photoPickerItems: [PhotosPickerItem] = []
    var photoPreviewImages: [UIImage] = []
    /// 相機拍攝（JPEG），與相簿選取分開儲存；預覽順序為相簿在前、拍照在後。
    var cameraPhotoJPEGs: [Data] = []
    var extraFiles: [(data: Data, name: String, mime: String)] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    var remainingPhotoSlots: Int {
        max(0, 30 - committedPhotoIds.count - photoPickerItems.count - cameraPhotoJPEGs.count)
    }

    var mergedLocalPhotoPreviews: [UIImage] {
        PhotoPickerPreviewLoader.mergedLocalPreviews(pickerUIImages: photoPreviewImages, cameraJPEGs: cameraPhotoJPEGs)
    }

    var remainingFileSlots: Int {
        max(0, 30 - committedFileAttachments.count - extraFiles.count)
    }

    func refreshPhotoPreviews() async {
        photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
    }

    func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task { await refreshPhotoPreviews() }
    }

    func appendCameraPhoto(_ image: UIImage) {
        guard remainingPhotoSlots > 0,
              let data = FieldCameraImageEncoding.jpegData(from: image) else { return }
        cameraPhotoJPEGs.append(data)
    }

    func removeMergedLocalPhoto(at index: Int) {
        let pickerCount = photoPreviewImages.count
        if index < pickerCount {
            removePhotoPickerItem(at: index)
        } else {
            let ci = index - pickerCount
            guard cameraPhotoJPEGs.indices.contains(ci) else { return }
            cameraPhotoJPEGs.remove(at: ci)
        }
    }

    func load(repair: RepairDetailDTO) {
        customerName = repair.customerName
        contactPhone = repair.contactPhone
        repairContent = repair.repairContent
        unitLabel = repair.unitLabel ?? ""
        remarks = repair.remarks ?? ""
        problemCategory = repair.problemCategory
        isSecondRepair = repair.isSecondRepair
        status = repair.status
        deliveryDateYMD = Self.apiDateToYMD(repair.deliveryDate)
        repairDateYMD = Self.apiDateToYMD(repair.repairDate)
        committedPhotoIds = repair.photos?.map(\.id) ?? []
        committedFileAttachments = repair.attachments?.map { ($0.id, $0.fileName) } ?? []
        photoPickerItems = []
        photoPreviewImages = []
        cameraPhotoJPEGs = []
        extraFiles = []
    }

    private static func apiDateToYMD(_ api: String?) -> String {
        guard let s = api?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return "" }
        if s.count >= 10 { return String(s.prefix(10)) }
        return s
    }

    func save(projectId: String, repairId: String, token: String) async -> Bool {
        errorMessage = nil
        let name = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = contactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = repairContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "請填寫客戶姓名"
            return false
        }
        guard !phone.isEmpty else {
            errorMessage = "請填寫聯絡電話"
            return false
        }
        guard !content.isEmpty else {
            errorMessage = "請填寫報修內容"
            return false
        }
        guard !problemCategory.isEmpty else {
            errorMessage = "請選擇問題類別"
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let ul = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let rm = remarks.trimmingCharacters(in: .whitespacesAndNewlines)
        let dd = deliveryDateYMD.trimmingCharacters(in: .whitespacesAndNewlines)
        let rd = repairDateYMD.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var newPhotoIds: [String] = []
            for item in photoPickerItems {
                guard newPhotoIds.count < 30 else { break }
                guard let data = await FieldPhotoUploadEncoding.jpegDataForUpload(fromPickerItem: item) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "photo.\(ext)"
                let mime = repairMimeForImageData(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "repair_photo"
                )
                newPhotoIds.append(up.id)
            }
            for jpeg in cameraPhotoJPEGs {
                guard newPhotoIds.count < 30 else { break }
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: jpeg,
                    fileName: "camera.jpg",
                    mimeType: "image/jpeg",
                    category: "repair_photo"
                )
                newPhotoIds.append(up.id)
            }

            var newFileIds: [String] = []
            for file in extraFiles {
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: file.data,
                    fileName: file.name,
                    mimeType: file.mime,
                    category: "repair_attachment"
                )
                newFileIds.append(up.id)
            }

            let mergedPhotos = repairUniqIdsPreservingOrder(committedPhotoIds + newPhotoIds)
            let mergedFiles = repairUniqIdsPreservingOrder(committedFileAttachments.map(\.id) + newFileIds)
            guard mergedPhotos.count <= 30, mergedFiles.count <= 30 else {
                errorMessage = "照片與附件各最多 30 個"
                return false
            }

            let body = UpdateRepairRequestBody(
                customerName: name,
                contactPhone: phone,
                repairContent: content,
                problemCategory: problemCategory,
                isSecondRepair: isSecondRepair,
                status: status,
                unitLabel: ul.isEmpty ? nil : ul,
                remarks: rm.isEmpty ? nil : rm,
                deliveryDate: dd.isEmpty ? nil : dd,
                repairDate: rd.isEmpty ? nil : rd,
                photoAttachmentIds: mergedPhotos,
                fileAttachmentIds: mergedFiles
            )

            _ = try await APIService.updateRepairRequest(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                repairId: repairId,
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

struct RepairEditView: View {
    let projectId: String
    let repairId: String
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm = RepairEditViewModel()
    @State private var showDocImporter = false
    @State private var showCamera = false

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
                        TacticalTextField(title: "客戶姓名", text: $edit.customerName, contentType: .name)
                        TacticalTextField(title: "聯絡電話", text: $edit.contactPhone, keyboard: .phonePad, contentType: .telephoneNumber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("報修內容".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("", text: $edit.repairContent, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(4 ... 10)
                                .textInputAutocapitalization(.sentences)
                                .padding(.vertical, 4)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.28))
                                .frame(height: 1)
                        }
                        Menu {
                            ForEach(RepairConstants.problemCategories, id: \.self) { cat in
                                Button(cat) { edit.problemCategory = cat }
                            }
                        } label: {
                            HStack {
                                Text(edit.problemCategory.isEmpty ? "選擇問題類別" : edit.problemCategory)
                                    .font(.subheadline)
                                    .foregroundStyle(edit.problemCategory.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        Toggle(isOn: $edit.isSecondRepair) {
                            Text("二次報修")
                                .font(.subheadline)
                        }
                        Picker("狀態", selection: $edit.status) {
                            Text("進行中").tag("in_progress")
                            Text("已完成").tag("completed")
                        }
                        .pickerStyle(.segmented)
                        TacticalTextField(title: "戶別（選填）", text: $edit.unitLabel)
                        TacticalTextField(title: "備註（選填）", text: $edit.remarks)
                        TacticalTextField(title: "交屋日 YYYY-MM-DD（選填）", text: $edit.deliveryDateYMD)
                        TacticalTextField(title: "修繕完成日 YYYY-MM-DD（選填）", text: $edit.repairDateYMD)
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("照片")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        FieldFormPhotoStrip(
                            remotePhotoIds: edit.committedPhotoIds,
                            localPreviewImages: edit.mergedLocalPhotoPreviews,
                            onRemoveRemote: { id in edit.committedPhotoIds.removeAll { $0 == id } },
                            onRemoveLocal: { index in edit.removeMergedLocalPhoto(at: index) }
                        )
                        FieldPhotoLibraryAndCameraButtons(
                            photoPickerItems: $edit.photoPickerItems,
                            maxPickerSelection: min(12, edit.remainingPhotoSlots),
                            remainingSlots: edit.remainingPhotoSlots,
                            showCamera: $showCamera,
                            photoLibraryTitle: "從相簿新增"
                        )
                        if edit.remainingPhotoSlots <= 0 {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(edit.committedPhotoIds.count + edit.photoPickerItems.count + edit.cameraPhotoJPEGs.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("附件")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        ForEach(edit.committedFileAttachments, id: \.id) { att in
                            HStack {
                                Text(att.fileName)
                                    .font(.tacticalMonoFixed(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button("移除") {
                                    edit.committedFileAttachments.removeAll { $0.id == att.id }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.tertiary)
                            }
                        }
                        if edit.remainingFileSlots > 0 {
                            Button {
                                showDocImporter = true
                            } label: {
                                Label("加入檔案", systemImage: "paperclip")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            }
                        } else {
                            Text("附件已達 30 個上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("附件 \(edit.committedFileAttachments.count + edit.extraFiles.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                        ForEach(Array(edit.extraFiles.enumerated()), id: \.offset) { _, f in
                            Text(f.name)
                                .font(.tacticalMonoFixed(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    Task {
                        let ok = await vm.save(projectId: projectId, repairId: repairId, token: accessToken)
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
        .sheet(isPresented: $showCamera) {
            FieldCameraImagePicker(isPresented: $showCamera) { image in
                edit.appendCameraPhoto(image)
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showDocImporter,
            allowedContentTypes: [.pdf, .plainText, .data, .image],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            let cap = edit.remainingFileSlots
            guard cap > 0 else { return }
            var taken = 0
            for url in urls {
                guard taken < cap else { break }
                let got = url.startAccessingSecurityScopedResource()
                defer {
                    if got { url.stopAccessingSecurityScopedResource() }
                }
                guard let data = try? Data(contentsOf: url) else { continue }
                let name = url.lastPathComponent
                let mime = repairMimeTypeForFileURL(url)
                edit.extraFiles.append((data, name, mime))
                taken += 1
            }
        }
        .navigationTitle("編輯報修")
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
                let r = try await APIService.getRepairRequest(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    repairId: repairId
                )
                vm.load(repair: r)
            } catch let api as APIRequestError {
                vm.errorMessage = api.localizedDescription
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Repair execution record create / edit

@MainActor
@Observable
final class RepairRecordCreateViewModel {
    var contentText = ""
    var photoPickerItems: [PhotosPickerItem] = []
    var photoPreviewImages: [UIImage] = []
    var cameraPhotoJPEGs: [Data] = []
    var isSubmitting = false
    var errorMessage: String?

    var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    var remainingPhotoSlots: Int {
        max(0, 30 - photoPickerItems.count - cameraPhotoJPEGs.count)
    }

    var mergedLocalPhotoPreviews: [UIImage] {
        PhotoPickerPreviewLoader.mergedLocalPreviews(pickerUIImages: photoPreviewImages, cameraJPEGs: cameraPhotoJPEGs)
    }

    func refreshPhotoPreviews() async {
        photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
    }

    func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task { await refreshPhotoPreviews() }
    }

    func appendCameraPhoto(_ image: UIImage) {
        guard remainingPhotoSlots > 0,
              let data = FieldCameraImageEncoding.jpegData(from: image) else { return }
        cameraPhotoJPEGs.append(data)
    }

    func removeMergedLocalPhoto(at index: Int) {
        let pickerCount = photoPreviewImages.count
        if index < pickerCount {
            removePhotoPickerItem(at: index)
        } else {
            let ci = index - pickerCount
            guard cameraPhotoJPEGs.indices.contains(ci) else { return }
            cameraPhotoJPEGs.remove(at: ci)
        }
    }

    func submit(
        projectId: String,
        repairId: String?,
        pendingRepairOutboxParentId: UUID?,
        token: String,
        outbox: FieldOutboxStore
    ) async -> Bool {
        errorMessage = nil
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "請填寫報修紀錄內容"
            return false
        }
        let hasServerRepair = repairId != nil && !(repairId!.isEmpty)
        let hasPendingParent = pendingRepairOutboxParentId != nil
        guard hasServerRepair || hasPendingParent else {
            errorMessage = "無法建立紀錄"
            return false
        }

        if !FieldNetworkMonitor.shared.isReachable {
            return await enqueueRepairRecordOutbox(
                projectId: projectId,
                repairId: repairId,
                pendingRepairOutboxParentId: pendingRepairOutboxParentId,
                text: text,
                outbox: outbox
            )
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            guard let rid = repairId, !rid.isEmpty else {
                errorMessage = "此報修尚未同步，請連線後再試或從待上傳項目新增紀錄"
                return false
            }
            var attachmentIds: [String] = []
            for item in photoPickerItems {
                guard attachmentIds.count < 30 else { break }
                guard let data = await FieldPhotoUploadEncoding.jpegDataForUpload(fromPickerItem: item) else { continue }
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
                    category: "repair_record"
                )
                attachmentIds.append(up.id)
            }
            for jpeg in cameraPhotoJPEGs {
                guard attachmentIds.count < 30 else { break }
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: jpeg,
                    fileName: "camera.jpg",
                    mimeType: "image/jpeg",
                    category: "repair_record"
                )
                attachmentIds.append(up.id)
            }
            guard attachmentIds.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return false
            }

            let body = CreateRepairExecutionRecordBody(content: text, attachmentIds: attachmentIds)
            _ = try await APIService.createRepairExecutionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: token,
                projectId: projectId,
                repairId: rid,
                body: body
            )
            return true
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
            if case .transport = api {
                return await enqueueRepairRecordOutbox(
                    projectId: projectId,
                    repairId: repairId,
                    pendingRepairOutboxParentId: pendingRepairOutboxParentId,
                    text: text,
                    outbox: outbox
                )
            }
            return false
        } catch {
            guard !error.isIgnorableTaskCancellation else { return false }
            if error.isLikelyConnectivityFailure {
                return await enqueueRepairRecordOutbox(
                    projectId: projectId,
                    repairId: repairId,
                    pendingRepairOutboxParentId: pendingRepairOutboxParentId,
                    text: text,
                    outbox: outbox
                )
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func enqueueRepairRecordOutbox(
        projectId: String,
        repairId: String?,
        pendingRepairOutboxParentId: UUID?,
        text: String,
        outbox: FieldOutboxStore
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            var mediaData: [String: Data] = [:]
            var photoMetas: [FieldOutboxMediaFile] = []
            var idx = 0
            for item in photoPickerItems {
                guard idx < 30, let data = await FieldPhotoUploadEncoding.jpegDataForUpload(fromPickerItem: item) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "record.\(ext)"
                let mime = mimeForImage(data: data, fallbackExtension: ext)
                let key = "r\(idx).\(ext)"
                mediaData[key] = data
                photoMetas.append(
                    FieldOutboxMediaFile(storedName: key, uploadFileName: fname, mimeType: mime, category: "repair_record")
                )
                idx += 1
            }
            for (j, jpeg) in cameraPhotoJPEGs.enumerated() {
                guard idx < 30 else { break }
                let key = "rcam\(j).jpg"
                mediaData[key] = jpeg
                photoMetas.append(
                    FieldOutboxMediaFile(storedName: key, uploadFileName: "camera.jpg", mimeType: "image/jpeg", category: "repair_record")
                )
                idx += 1
            }
            guard idx <= 30 else {
                errorMessage = "照片最多 30 張"
                return false
            }

            let payload = FieldOutboxRepairRecordPayload(
                repairId: repairId,
                dependsOnRepairOutboxId: pendingRepairOutboxParentId,
                content: text,
                photos: photoMetas
            )
            try outbox.enqueueRepairRecord(
                projectId: projectId,
                title: "報修執行紀錄",
                repairId: repairId,
                dependsOnRepairOutboxId: pendingRepairOutboxParentId,
                payload: payload,
                mediaData: mediaData
            )
            return true
        } catch {
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

struct RepairRecordCreateView: View {
    let projectId: String
    let repairId: String?
    let pendingRepairOutboxParentId: UUID?
    let accessToken: String
    var onFinished: () async -> Void

    init(projectId: String, repairId: String, accessToken: String, onFinished: @escaping () async -> Void) {
        self.projectId = projectId
        self.repairId = repairId
        self.pendingRepairOutboxParentId = nil
        self.accessToken = accessToken
        self.onFinished = onFinished
    }

    init(projectId: String, pendingRepairOutboxParentId: UUID, accessToken: String, onFinished: @escaping () async -> Void) {
        self.projectId = projectId
        self.repairId = nil
        self.pendingRepairOutboxParentId = pendingRepairOutboxParentId
        self.accessToken = accessToken
        self.onFinished = onFinished
    }

    @Environment(FieldOutboxStore.self) private var fieldOutbox
    @Environment(\.dismiss) private var dismiss
    @State private var createModel = RepairRecordCreateViewModel()
    @State private var showCamera = false

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
                            Text("報修紀錄內容".uppercased())
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
                        FieldFormPhotoStrip(
                            remotePhotoIds: [],
                            localPreviewImages: model.mergedLocalPhotoPreviews,
                            onRemoveRemote: { _ in },
                            onRemoveLocal: { index in model.removeMergedLocalPhoto(at: index) }
                        )
                        FieldPhotoLibraryAndCameraButtons(
                            photoPickerItems: $model.photoPickerItems,
                            maxPickerSelection: min(12, model.remainingPhotoSlots),
                            remainingSlots: model.remainingPhotoSlots,
                            showCamera: $showCamera,
                            photoLibraryTitle: "從相簿新增"
                        )
                        if model.remainingPhotoSlots <= 0 {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(model.photoPickerItems.count + model.cameraPhotoJPEGs.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    Task {
                        let ok = await createModel.submit(
                            projectId: projectId,
                            repairId: repairId,
                            pendingRepairOutboxParentId: pendingRepairOutboxParentId,
                            token: accessToken,
                            outbox: fieldOutbox
                        )
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
        .sheet(isPresented: $showCamera) {
            FieldCameraImagePicker(isPresented: $showCamera) { image in
                model.appendCameraPhoto(image)
            }
            .ignoresSafeArea()
        }
        .navigationTitle(pendingRepairOutboxParentId != nil ? "新增紀錄（待同步報修）" : "新增報修紀錄")
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

struct RepairRecordEditView: View {
    let projectId: String
    let repairId: String
    let record: RepairExecutionRecordDTO
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentText = ""
    @State private var committedPhotoIds: [String] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var photoPreviewImages: [UIImage] = []
    @State private var cameraPhotoJPEGs: [Data] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showCamera = false

    private var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    private var remainingPhotoSlots: Int {
        max(0, 30 - committedPhotoIds.count - photoPickerItems.count - cameraPhotoJPEGs.count)
    }

    private var mergedLocalPhotoPreviews: [UIImage] {
        PhotoPickerPreviewLoader.mergedLocalPreviews(pickerUIImages: photoPreviewImages, cameraJPEGs: cameraPhotoJPEGs)
    }

    private func removePhotoPickerItem(at index: Int) {
        guard photoPickerItems.indices.contains(index) else { return }
        photoPickerItems.remove(at: index)
        Task {
            photoPreviewImages = await PhotoPickerPreviewLoader.uiImages(from: photoPickerItems)
        }
    }

    private func appendCameraPhoto(_ image: UIImage) {
        guard remainingPhotoSlots > 0,
              let data = FieldCameraImageEncoding.jpegData(from: image) else { return }
        cameraPhotoJPEGs.append(data)
    }

    private func removeMergedLocalPhoto(at index: Int) {
        let pickerCount = photoPreviewImages.count
        if index < pickerCount {
            removePhotoPickerItem(at: index)
        } else {
            let ci = index - pickerCount
            guard cameraPhotoJPEGs.indices.contains(ci) else { return }
            cameraPhotoJPEGs.remove(at: ci)
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
                            Text("報修紀錄內容".uppercased())
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
                            remotePhotoIds: committedPhotoIds,
                            localPreviewImages: mergedLocalPhotoPreviews,
                            onRemoveRemote: { id in committedPhotoIds.removeAll { $0 == id } },
                            onRemoveLocal: { index in removeMergedLocalPhoto(at: index) }
                        )
                        FieldPhotoLibraryAndCameraButtons(
                            photoPickerItems: $photoPickerItems,
                            maxPickerSelection: min(12, remainingPhotoSlots),
                            remainingSlots: remainingPhotoSlots,
                            showCamera: $showCamera,
                            photoLibraryTitle: "從相簿新增"
                        )
                        if remainingPhotoSlots <= 0 {
                            Text("照片已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        Text("照片 \(committedPhotoIds.count + photoPickerItems.count + cameraPhotoJPEGs.count)／30")
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
        .sheet(isPresented: $showCamera) {
            FieldCameraImagePicker(isPresented: $showCamera) { image in
                appendCameraPhoto(image)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("編輯報修紀錄")
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
                guard newIds.count < 30 else { break }
                guard let data = await FieldPhotoUploadEncoding.jpegDataForUpload(fromPickerItem: item) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "record.\(ext)"
                let mime = repairMimeForImageData(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "repair_record"
                )
                newIds.append(up.id)
            }
            for jpeg in cameraPhotoJPEGs {
                guard newIds.count < 30 else { break }
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    fileData: jpeg,
                    fileName: "camera.jpg",
                    mimeType: "image/jpeg",
                    category: "repair_record"
                )
                newIds.append(up.id)
            }
            let merged = repairUniqIdsPreservingOrder(committedPhotoIds + newIds)
            guard merged.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return
            }
            _ = try await APIService.updateRepairExecutionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                repairId: repairId,
                recordId: record.id,
                body: UpdateRepairExecutionRecordBody(content: text, attachmentIds: merged)
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
