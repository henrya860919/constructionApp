//
//  SelfInspectionModuleView.swift
//  constructionApp
//
//  自主查驗：已匯入樣板列表 → 紀錄列表（FAB 新增）→ 填寫（表頭 + 全時機區塊檢查項，通過／不通過）。
//

import Combine
import PhotosUI
import SwiftUI
import UIKit

// MARK: - View models

@MainActor
@Observable
final class SelfInspectionTemplatesListViewModel {
    var templates: [SelfInspectionProjectTemplateDTO] = []
    var isLoading = false
    var errorMessage: String?

    func load(projectId: String, session: SessionManager) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            templates = try await session.withValidAccessToken { token in
                try await APIService.listSelfInspectionTemplates(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId
                )
            }
            FieldSelfInspectionTemplatesSnapshotStore.save(projectId: projectId, templates: templates)
            let templateIds = templates.map(\.id)
            Task { @MainActor in
                await SelfInspectionTemplateHubPrefetch.prefetchAllHubs(
                    projectId: projectId,
                    templateIds: templateIds,
                    session: session
                )
            }
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            if error.isLikelyConnectivityFailure,
               let snap = FieldSelfInspectionTemplatesSnapshotStore.load(projectId: projectId) {
                templates = snap
                errorMessage = nil
            } else if let api = error as? APIRequestError {
                errorMessage = api.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
@Observable
final class SelfInspectionRecordsListViewModel {
    var records: [SelfInspectionRecordListDTO] = []
    var meta: PageMetaDTO?
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    /// 最近一次列表載入是否因連線問題失敗（供離線還原快照）。
    private(set) var lastLoadFailedOffline = false

    var hasMore: Bool {
        guard let meta else { return false }
        return records.count < meta.total
    }

    func load(projectId: String, templateId: String, session: SessionManager) async {
        isLoading = true
        errorMessage = nil
        lastLoadFailedOffline = false
        defer { isLoading = false }
        do {
            let env = try await session.withValidAccessToken { token in
                try await APIService.listSelfInspectionRecords(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    templateId: templateId,
                    page: 1,
                    limit: FieldListPagination.pageSize
                )
            }
            records = env.data
            meta = env.meta
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            lastLoadFailedOffline = error.isLikelyConnectivityFailure
            if let api = error as? APIRequestError {
                errorMessage = api.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMore(projectId: String, templateId: String, session: SessionManager) async {
        guard let m = meta, hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = m.page + 1
        do {
            let env = try await session.withValidAccessToken { token in
                try await APIService.listSelfInspectionRecords(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    templateId: templateId,
                    page: nextPage,
                    limit: FieldListPagination.pageSize
                )
            }
            let existing = Set(records.map(\.id))
            let newRows = env.data.filter { !existing.contains($0.id) }
            records.append(contentsOf: newRows)
            meta = env.meta
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            if error.isLikelyConnectivityFailure, !records.isEmpty {
                return
            }
            if let api = error as? APIRequestError {
                errorMessage = api.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Form state（新增／編輯共用）

@MainActor
@Observable
final class SelfInspectionRecordFormState {
    var inspectionName = ""
    var subProjectName = ""
    var subcontractor = ""
    var inspectionLocation = ""
    var inspectionDate = Date()
    var timingOptionId = ""
    var itemResults: [String: String] = [:]
    /// 已上傳並將一併送出的附件 id（編輯時自詳情載入）
    var committedPhotoIds: [String] = []
    var photoPickerItems: [PhotosPickerItem] = []
    var photoPreviewImages: [UIImage] = []
    var cameraPhotoJPEGs: [Data] = []

    var photoPickerFingerprint: String {
        PhotoPickerPreviewLoader.fingerprint(for: photoPickerItems)
    }

    var remainingPhotoSlots: Int {
        max(0, 30 - committedPhotoIds.count - photoPickerItems.count - cameraPhotoJPEGs.count)
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

    func apply(detail: SelfInspectionRecordDetailDTO) {
        let h = detail.filledPayload?.header
        inspectionName = h?.inspectionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        subProjectName = h?.subProjectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        subcontractor = h?.subcontractor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        inspectionLocation = h?.inspectionLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let raw = h?.inspectionDate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            inspectionDate = dateFromInspectionYMD(raw) ?? Date()
        } else {
            inspectionDate = Date()
        }
        timingOptionId = h?.timingOptionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        committedPhotoIds = detail.filledPayload?.photoAttachmentIds ?? []
        photoPickerItems = []
        photoPreviewImages = []
        cameraPhotoJPEGs = []
        itemResults = [:]
        if let entries = detail.filledPayload?.items {
            for (key, row) in entries {
                if let raw = row.resultOptionId?.trimmingCharacters(in: .whitespacesAndNewlines), let rid = raw.nilIfEmpty {
                    itemResults[key] = rid
                }
            }
        }
    }
}

private struct SelfInspectionEditSheetTarget: Identifiable {
    let id: String
}

private func selfInspectionCompletedCount(
    expectedItemIds: Set<String>,
    payload: SelfInspectionFilledPayloadLight?
) -> Int {
    guard let items = payload?.items, !expectedItemIds.isEmpty else { return 0 }
    var n = 0
    for id in expectedItemIds {
        guard let row = items[id] else { continue }
        let r = row.resultOptionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !r.isEmpty { n += 1 }
    }
    return n
}

/// 與表單／詳情 `passAndFailIds` 一致，用於列表統計不合格筆數。
private func selfInspectionPassFailIds(from options: [SelfInspectionOptionDTO]) -> (passId: String, failId: String) {
    if let p = options.first(where: { $0.id == "pass" }),
       let f = options.first(where: { $0.id == "fail" }) {
        return (p.id, f.id)
    }
    if options.count >= 2 {
        return (options[0].id, options[1].id)
    }
    let only = options.first?.id ?? "pass"
    return (only, only)
}

/// 樣板預期查驗列中，勾選為「不通過」的數量（`failId` 須與 `passId` 不同才有效）。
private func selfInspectionFailItemCount(
    expectedItemIds: Set<String>,
    failId: String,
    payload: SelfInspectionFilledPayloadLight?
) -> Int {
    guard !expectedItemIds.isEmpty, let items = payload?.items else { return 0 }
    var n = 0
    for id in expectedItemIds {
        guard let row = items[id] else { continue }
        let r = row.resultOptionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if r == failId { n += 1 }
    }
    return n
}

private func dateFromInspectionYMD(_ s: String) -> Date? {
    let parts = s.split(separator: "-").map(String.init)
    guard parts.count == 3,
          let y = Int(parts[0]),
          let m = Int(parts[1]),
          let d = Int(parts[2]) else { return nil }
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    return Calendar.current.date(from: c)
}

// MARK: - 樣板 hub 預載（離線新增需各樣板欄位／檢查項）

private enum SelfInspectionTemplateHubPrefetch {
    /// 在樣板列表成功載入後於背景執行；逐一下載各樣板 hub 並合併至快照，不阻塞列表 UI。
    @MainActor
    static func prefetchAllHubs(
        projectId: String,
        templateIds: [String],
        session: SessionManager
    ) async {
        guard FieldNetworkMonitor.shared.isReachable else { return }
        for templateId in templateIds {
            guard FieldNetworkMonitor.shared.isReachable else { break }
            do {
                let hub = try await session.withValidAccessToken { token in
                    try await APIService.getSelfInspectionTemplateHub(
                        baseURL: AppConfiguration.apiRootURL,
                        token: token,
                        projectId: projectId,
                        templateId: templateId
                    )
                }
                FieldSelfInspectionTemplateRecordsSnapshotStore.mergeHub(
                    projectId: projectId,
                    templateId: templateId,
                    hub: hub
                )
            } catch {
                guard !error.isIgnorableTaskCancellation else { return }
                // 單一樣板失敗不中斷其餘預載
                continue
            }
        }
    }
}

// MARK: - Navigation

private struct SelfInspectionTemplateRoute: Hashable {
    let templateId: String
    let templateName: String
}

private enum SelfInspectionRecordListDestination: Hashable {
    case serverRecord(id: String)
    case pendingOutbox(entryId: UUID)
}

// MARK: - Module root

struct SelfInspectionModuleView: View {
    @Environment(SessionManager.self) private var session
    @State private var model = SelfInspectionTemplatesListViewModel()
    @State private var navigateTo: SelfInspectionTemplateRoute?

    var body: some View {
        Group {
            if let pid = session.selectedProjectId, session.isAuthenticated {
                SelfInspectionTemplatesListContent(
                    projectId: pid,
                    model: model,
                    navigateTo: $navigateTo
                )
                .navigationDestination(item: $navigateTo) { route in
                    SelfInspectionTemplateRecordsView(
                        projectId: pid,
                        templateId: route.templateId,
                        templateName: route.templateName
                    )
                }
            } else {
                Text("缺少專案或登入狀態")
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TacticalGlassTheme.surface)
        .task {
            if let pid = session.selectedProjectId, session.isAuthenticated {
                await model.load(projectId: pid, session: session)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldRemoteDataShouldRefresh)) { _ in
            Task {
                if let pid = session.selectedProjectId, session.isAuthenticated {
                    await model.load(projectId: pid, session: session)
                }
            }
        }
    }
}

// MARK: - Templates list

private struct SelfInspectionTemplatesListContent: View {
    @Environment(SessionManager.self) private var session
    let projectId: String
    @Bindable var model: SelfInspectionTemplatesListViewModel
    @Binding var navigateTo: SelfInspectionTemplateRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            obsidianModuleHeader(title: "自主查驗")
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text("選擇已匯入專案之樣板，檢視或新增查驗紀錄。")
                .font(.subheadline)
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if let err = model.errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(TacticalGlassTheme.tertiary)
                        Text("無法載入樣板")
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
            }

            if model.isLoading && model.templates.isEmpty {
                Spacer()
                ProgressView("載入中…")
                    .tint(TacticalGlassTheme.primary)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if model.templates.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text("尚無匯入樣板")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("請至儀表板將自主檢查樣板匯入本專案後，即可於此填寫紀錄。")
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(model.templates) { t in
                        Button {
                            navigateTo = SelfInspectionTemplateRoute(templateId: t.id, templateName: t.name)
                        } label: {
                            templateRow(t)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, TacticalGlassTheme.tabBarScrollBottomMargin, for: .scrollContent)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.defaultMinListRowHeight, 8)
                .refreshable {
                    await model.load(projectId: projectId, session: session)
                }
            }
        }
    }

    private func templateRow(_ t: SelfInspectionProjectTemplateDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(t.recordCount) 筆")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TacticalGlassTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(TacticalGlassTheme.primary.opacity(0.18)))
            }
            if let desc = t.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
        }
    }
}

// MARK: - Records list + FAB

struct SelfInspectionTemplateRecordsView: View {
    @Environment(SessionManager.self) private var session
    @Environment(FieldOutboxStore.self) private var outbox

    let projectId: String
    let templateId: String
    let templateName: String

    @State private var model = SelfInspectionRecordsListViewModel()
    @State private var templateHub: SelfInspectionTemplateHubDTO?
    @State private var showCreate = false
    @State private var fabScrollIdle = true
    @State private var navigateToRecord: SelfInspectionRecordListDestination?
    @State private var editSheetTarget: SelfInspectionEditSheetTarget?
    @State private var recordIdPendingDelete: String?
    /// 與報修／缺失列表相同：Outbox 經 Environment 時需靠通知強制刷新待上傳列。
    @State private var outboxRefreshEpoch: UInt = 0

    private var expectedItemIds: Set<String> {
        guard let hub = templateHub else { return [] }
        return Set(hub.blocks.flatMap(\.items).map(\.id))
    }

    /// 用於判斷「不通過」選項 id；無樣板或僅單一結果選項時為 `nil`。
    private var inspectionDistinctFailId: String? {
        guard let hub = templateHub else { return nil }
        let (passId, failId) = selfInspectionPassFailIds(from: hub.template.headerConfig.resultLegendOptions)
        guard passId != failId else { return nil }
        return failId
    }

    private var pendingSelfInspectionRecords: [FieldOutboxIndexRecord] {
        _ = outboxRefreshEpoch
        return outbox.records(forProjectId: projectId).filter {
            $0.kind == .selfInspectionRecordCreate && $0.templateId == templateId
        }
    }

    private var showRecordsEmptyPlaceholder: Bool {
        model.records.isEmpty && pendingSelfInspectionRecords.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                if let err = model.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(TacticalGlassTheme.tertiary)
                            Text("無法載入紀錄")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("重試") {
                            Task { await reloadHubAndRecords() }
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
                    .padding(.top, 8)
                }

                if model.isLoading && showRecordsEmptyPlaceholder {
                    Spacer()
                    ProgressView("載入中…")
                        .tint(TacticalGlassTheme.primary)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if showRecordsEmptyPlaceholder {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        Text("尚無查驗紀錄")
                            .font(.subheadline)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(pendingSelfInspectionRecords) { rec in
                            Button {
                                navigateToRecord = .pendingOutbox(entryId: rec.id)
                            } label: {
                                selfInspectionPendingOutboxRow(rec)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        ForEach(model.records) { rec in
                            Button {
                                navigateToRecord = .serverRecord(id: rec.id)
                            } label: {
                                selfInspectionRecordRow(
                                    rec,
                                    expectedItemIds: expectedItemIds,
                                    distinctFailId: inspectionDistinctFailId
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editSheetTarget = SelfInspectionEditSheetTarget(id: rec.id)
                                } label: {
                                    Label("編輯", systemImage: "pencil")
                                }
                                .tint(TacticalGlassTheme.primary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    recordIdPendingDelete = rec.id
                                } label: {
                                    Label("刪除", systemImage: "trash.fill")
                                }
                            }
                        }
                        if model.hasMore {
                            Button {
                                Task { await model.loadMore(projectId: projectId, templateId: templateId, session: session) }
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
                    .contentMargins(.bottom, TacticalGlassTheme.tabBarScrollBottomMargin, for: .scrollContent)
                    .scrollDismissesKeyboard(.interactively)
                    .environment(\.defaultMinListRowHeight, 8)
                    .refreshable {
                        await reloadHubAndRecords()
                    }
                    .fieldFABScrollIdleTracking($fabScrollIdle)
                }
            }

            Button {
                showCreate = true
            } label: {
                ObsidianSquareFAB(accessibilityLabel: "新增查驗紀錄")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, TacticalGlassTheme.fieldFABBottomInset)
            .opacity(fabScrollIdle ? 1 : 0)
            .allowsHitTesting(fabScrollIdle)
            .animation(.easeInOut(duration: 0.2), value: fabScrollIdle)
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle(templateName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $navigateToRecord) { dest in
            switch dest {
            case .serverRecord(let recordId):
                SelfInspectionRecordDetailView(
                    projectId: projectId,
                    templateId: templateId,
                    recordId: recordId,
                    pendingOutboxEntryId: nil,
                    accessToken: session.accessToken ?? "",
                    projectDisplayName: session.selectedProjectName ?? ""
                ) {
                    await reloadHubAndRecords()
                }
            case .pendingOutbox(let entryId):
                SelfInspectionRecordDetailView(
                    projectId: projectId,
                    templateId: templateId,
                    recordId: entryId.uuidString,
                    pendingOutboxEntryId: entryId,
                    accessToken: session.accessToken ?? "",
                    projectDisplayName: session.selectedProjectName ?? ""
                ) {
                    await reloadHubAndRecords()
                }
            }
        }
        .task {
            await reloadHubAndRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldRemoteDataShouldRefresh)) { _ in
            Task {
                await reloadHubAndRecords()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldOutboxDidChange)) { _ in
            outboxRefreshEpoch += 1
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                SelfInspectionCreateRecordView(
                    projectId: projectId,
                    accessToken: session.accessToken ?? "",
                    templateId: templateId,
                    projectDisplayName: session.selectedProjectName ?? ""
                ) {
                    await reloadHubAndRecords()
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $editSheetTarget) { target in
            NavigationStack {
                SelfInspectionEditRecordView(
                    projectId: projectId,
                    accessToken: session.accessToken ?? "",
                    templateId: templateId,
                    recordId: target.id,
                    projectDisplayName: session.selectedProjectName ?? ""
                ) {
                    await reloadHubAndRecords()
                }
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(
            "確定刪除此筆查驗紀錄？此動作無法復原。",
            isPresented: Binding(
                get: { recordIdPendingDelete != nil },
                set: { if !$0 { recordIdPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) {
                guard let id = recordIdPendingDelete else { return }
                recordIdPendingDelete = nil
                Task {
                    await deleteRecord(recordId: id)
                }
            }
            Button("取消", role: .cancel) {
                recordIdPendingDelete = nil
            }
        }
    }

    private func reloadHubAndRecords() async {
        let snap = FieldSelfInspectionTemplateRecordsSnapshotStore.load(projectId: projectId, templateId: templateId)
        var hubFromAPI: SelfInspectionTemplateHubDTO?
        do {
            hubFromAPI = try await session.withValidAccessToken { token in
                try await APIService.getSelfInspectionTemplateHub(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    templateId: templateId
                )
            }
            templateHub = hubFromAPI
        } catch {
            if error.isLikelyConnectivityFailure, let h = snap?.hub {
                templateHub = h
            } else {
                templateHub = nil
            }
        }

        await model.load(projectId: projectId, templateId: templateId, session: session)

        if model.errorMessage != nil, model.lastLoadFailedOffline, let s = snap {
            model.records = s.records
            model.meta = s.meta
            model.errorMessage = nil
            if templateHub == nil {
                templateHub = s.hub
            }
        }

        if templateHub != nil, model.errorMessage == nil, let h = templateHub {
            FieldSelfInspectionTemplateRecordsSnapshotStore.save(
                projectId: projectId,
                templateId: templateId,
                hub: h,
                records: model.records,
                meta: model.meta
            )
        }
    }

    private func deleteRecord(recordId: String) async {
        do {
            try await session.withValidAccessToken { token in
                try await APIService.deleteSelfInspectionRecord(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    templateId: templateId,
                    recordId: recordId
                )
            }
            await reloadHubAndRecords()
        } catch {
            await MainActor.run {
                model.errorMessage = (error as? APIRequestError)?.localizedDescription ?? error.localizedDescription
            }
        }
    }

    private func selfInspectionPendingOutboxRow(_ rec: FieldOutboxIndexRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(rec.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
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
            Text("連線後將建立於伺服器。")
                .font(.footnote)
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.primary.opacity(0.28), lineWidth: 1)
        }
    }

    private func selfInspectionRecordRow(
        _ rec: SelfInspectionRecordListDTO,
        expectedItemIds: Set<String>,
        distinctFailId: String?
    ) -> some View {
        let title = rec.filledPayload?.header?.inspectionName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let dateLine = rec.filledPayload?.header?.inspectionDate?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let who = rec.filledBy?.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? rec.filledBy?.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let done = selfInspectionCompletedCount(expectedItemIds: expectedItemIds, payload: rec.filledPayload)
        let total = expectedItemIds.count
        let ratio = total > 0 ? Double(done) / Double(total) : 0
        let isComplete = total > 0 && done >= total
        let failCount = distinctFailId.map {
            selfInspectionFailItemCount(expectedItemIds: expectedItemIds, failId: $0, payload: rec.filledPayload)
        } ?? 0
        let hasFailItems = failCount > 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title ?? "查驗紀錄")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(shortDate(from: rec.createdAt))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }
            if let dateLine {
                Text("檢查日期：\(dateLine)")
                    .font(.footnote)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }
            if let who {
                Text("填寫：\(who)")
                    .font(.footnote)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }

            if total == 0 {
                Text("檢查進度：載入樣板中…")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("檢查進度 \(done)/\(total)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        Spacer()
                        if hasFailItems {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text(failCount == 1 ? "1 項不合格" : "\(failCount) 項不合格")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.tertiary)
                        } else if isComplete {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("已完成")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.primary)
                        }
                    }
                    ProgressView(value: ratio)
                        .tint(hasFailItems ? TacticalGlassTheme.tertiary : TacticalGlassTheme.primary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(
                    hasFailItems ? TacticalGlassTheme.tertiary.opacity(0.55) : TacticalGlassTheme.ghostBorder,
                    lineWidth: hasFailItems ? 1.5 : 1
                )
        }
    }

    private func shortDate(from iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "zh_TW")
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: d)
        }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: iso) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "zh_TW")
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: d)
        }
        return String(iso.prefix(16))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
