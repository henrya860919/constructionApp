//
//  DrawingManagementView.swift
//  constructionApp
//

import SwiftUI

// MARK: - Search（僅葉節點圖說名稱；搜尋頁只列圖說項目、不列資料夾）

private enum DrawingLeafSearch {
    /// 走訪整棵樹，回傳所有名稱符合關鍵字的**葉節點**（不比對資料夾名、檔名）。
    static func matchingLeaves(in roots: [DrawingNodeDTO], query raw: String) -> [DrawingNodeDTO] {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var out: [DrawingNodeDTO] = []
        func walk(_ nodes: [DrawingNodeDTO]) {
            for n in nodes {
                if n.isFolder, let children = n.children {
                    walk(children)
                } else if n.isLeaf, n.name.localizedCaseInsensitiveContains(q) {
                    out.append(n)
                }
            }
        }
        walk(roots)
        return out.sorted { a, b in
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}

// MARK: - View model

@MainActor
@Observable
final class DrawingTreeViewModel {
    var tree: [DrawingNodeDTO] = []
    var searchQuery = ""
    var isLoading = false
    var errorMessage: String?
    private(set) var revisionsByNodeId: [String: [DrawingRevisionDTO]] = [:]
    private var revisionsInFlight = Set<String>()

    func load(projectId: String, session: SessionManager) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let nodes = try await session.withValidAccessToken { token in
                try await APIService.listDrawingNodes(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId
                )
            }
            tree = nodes
            revisionsByNodeId = [:]
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func node(byId id: String) -> DrawingNodeDTO? {
        Self.findNode(id: id, in: tree)
    }

    private static func findNode(id: String, in nodes: [DrawingNodeDTO]) -> DrawingNodeDTO? {
        for n in nodes {
            if n.id == id { return n }
            if let ch = n.children, let found = findNode(id: id, in: ch) { return found }
        }
        return nil
    }

    func loadRevisionsIfNeeded(projectId: String, nodeId: String, session: SessionManager) async {
        if revisionsByNodeId[nodeId] != nil { return }
        if revisionsInFlight.contains(nodeId) { return }
        revisionsInFlight.insert(nodeId)
        defer { revisionsInFlight.remove(nodeId) }
        do {
            let list = try await session.withValidAccessToken { token in
                try await APIService.listDrawingRevisions(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    nodeId: nodeId
                )
            }
            revisionsByNodeId[nodeId] = list
        } catch {
            revisionsByNodeId[nodeId] = []
        }
    }
}

// MARK: - Quick Look session

private struct DrawingQuickLookSession: Identifiable {
    let id = UUID()
    let fileURL: URL
    let title: String?
}

// MARK: - Navigation

private extension View {
    func drawingFolderNavigation(projectId: String, vm: DrawingTreeViewModel) -> some View {
        navigationDestination(for: String.self) { folderId in
            DrawingFolderDrillDownView(projectId: projectId, folderNodeId: folderId, vm: vm)
        }
    }
}

// MARK: - Root

struct DrawingManagementRootView: View {
    @Environment(SessionManager.self) private var session
    @Environment(FieldNetworkMonitor.self) private var network
    @State private var vm = DrawingTreeViewModel()
    @State private var searchSessionPresented = false
    @State private var offlinePreviewListPresented = false

    var body: some View {
        Group {
            if let pid = session.selectedProjectId, session.isAuthenticated {
                mainStack(projectId: pid)
            } else {
                Text("缺少專案或登入狀態")
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TacticalGlassTheme.surface)
    }

    @ViewBuilder
    private func mainStack(projectId: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            obsidianModuleHeader(title: "圖說管理")
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Button {
                searchSessionPresented = true
            } label: {
                ObsidianListSearchPillAffordance(
                    placeholder: "搜尋圖說項目名稱…",
                    activeQuerySummary: vm.searchQuery
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            if !network.isReachable {
                Button {
                    offlinePreviewListPresented = true
                } label: {
                    obsidianDrawingAuxiliaryRow(
                        systemImage: "doc.text.magnifyingglass",
                        title: "離線圖說預覽",
                        subtitle: "僅列出本專案已預先下載、可離線開啟的檔案"
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(TacticalGlassTheme.statusDanger)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            DrawingNodesListBody(
                projectId: projectId,
                nodes: vm.tree,
                vm: vm,
                bottomContentMargin: TacticalGlassTheme.tabBarScrollBottomMargin
            )
        }
        .drawingFolderNavigation(projectId: projectId, vm: vm)
        .navigationDestination(isPresented: $searchSessionPresented) {
            DrawingManagementSearchSessionView(projectId: projectId, vm: vm)
        }
        .navigationDestination(isPresented: $offlinePreviewListPresented) {
            DrawingOfflinePreviewListView(projectId: projectId, vm: vm)
        }
        .task(id: projectId) {
            await vm.load(projectId: projectId, session: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldRemoteDataShouldRefresh)) { _ in
            Task {
                await vm.load(projectId: projectId, session: session)
            }
        }
    }

    @ViewBuilder
    private func obsidianDrawingAuxiliaryRow(systemImage: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.primary)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainer)
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
        }
    }
}

// MARK: - 離線：已預載檔案列表（Quick Look）

private struct DrawingOfflinePreviewListView: View {
    let projectId: String
    @Bindable var vm: DrawingTreeViewModel
    @State private var quickLookSession: DrawingQuickLookSession?
    @State private var storeRefreshTick: UInt = 0

    private var sortedEntries: [OfflineDrawingIndexEntry] {
        _ = storeRefreshTick
        return FieldOfflineDrawingStore.entries(forProjectId: projectId).sorted { a, b in
            let na = vm.node(byId: a.nodeId)?.name ?? a.fileName
            let nb = vm.node(byId: b.nodeId)?.name ?? b.fileName
            return na.localizedStandardCompare(nb) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    Text("尚無已預載的圖說檔案")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("本列表僅顯示已下載至離線圖說空間的檔案。釋出空間請至「設定」→「儲存空間」。")
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedEntries) { entry in
                        Button {
                            openPreview(entry)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "doc.richtext")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.primary.opacity(0.95))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vm.node(byId: entry.nodeId)?.name ?? entry.fileName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)
                                    Text(entry.fileName)
                                        .font(.caption)
                                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "eye.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                            }
                            .padding(.vertical, 4)
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
            }
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("離線圖說預覽")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(item: $quickLookSession) { session in
            FieldQuickLookPreviewSheet(fileURL: session.fileURL, title: session.title)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldCacheStorageDidChange)) { _ in
            storeRefreshTick &+= 1
        }
    }

    private func openPreview(_ entry: OfflineDrawingIndexEntry) {
        guard
            let url = FieldOfflineDrawingStore.temporaryURLForQuickLook(
                projectId: projectId,
                attachmentId: entry.attachmentId,
                displayFileName: entry.fileName
            )
        else { return }
        quickLookSession = DrawingQuickLookSession(fileURL: url, title: entry.fileName)
    }
}

// MARK: - Search session（只列出符合的圖說葉節點，不顯示資料夾）

private struct DrawingManagementSearchSessionView: View {
    let projectId: String
    @Bindable var vm: DrawingTreeViewModel
    @FocusState private var searchFieldFocused: Bool

    private var matchingLeaves: [DrawingNodeDTO] {
        DrawingLeafSearch.matchingLeaves(in: vm.tree, query: vm.searchQuery)
    }

    private var trimmedQuery: String {
        vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ObsidianSearchModePillField(
                text: $vm.searchQuery,
                placeholder: "搜尋圖說項目名稱…",
                isFocused: $searchFieldFocused
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)

            DrawingLeafSearchResultsBody(
                projectId: projectId,
                vm: vm,
                matchingLeaves: matchingLeaves,
                trimmedQuery: trimmedQuery,
                bottomContentMargin: 28
            )
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("搜尋圖說")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                searchFieldFocused = true
            }
        }
    }
}

private struct DrawingLeafSearchResultsBody: View {
    let projectId: String
    @Bindable var vm: DrawingTreeViewModel
    let matchingLeaves: [DrawingNodeDTO]
    let trimmedQuery: String
    var bottomContentMargin: CGFloat

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if vm.isLoading, vm.tree.isEmpty {
                    ProgressView()
                        .tint(TacticalGlassTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if trimmedQuery.isEmpty {
                    Text("輸入圖說項目名稱，將列出專案內所有符合的圖說（不含資料夾）。")
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                } else if matchingLeaves.isEmpty {
                    Text("找不到符合的圖說項目")
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else {
                    ForEach(matchingLeaves) { leaf in
                        DrawingLeafCardView(projectId: projectId, node: leaf, vm: vm)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, bottomContentMargin)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Folder level

private struct DrawingFolderDrillDownView: View {
    let projectId: String
    let folderNodeId: String
    @Bindable var vm: DrawingTreeViewModel

    private var folder: DrawingNodeDTO? {
        vm.node(byId: folderNodeId)
    }

    var body: some View {
        Group {
            if let folder, folder.isFolder {
                DrawingNodesListBody(
                    projectId: projectId,
                    nodes: folder.children ?? [],
                    vm: vm,
                    bottomContentMargin: TacticalGlassTheme.tabBarScrollBottomMargin
                )
                .navigationTitle(folder.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("找不到資料夾")
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TacticalGlassTheme.surface)
        .drawingFolderNavigation(projectId: projectId, vm: vm)
    }
}

// MARK: - List body

private struct DrawingNodesListBody: View {
    let projectId: String
    let nodes: [DrawingNodeDTO]
    @Bindable var vm: DrawingTreeViewModel
    var bottomContentMargin: CGFloat

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if vm.isLoading, nodes.isEmpty {
                    ProgressView()
                        .tint(TacticalGlassTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if !vm.isLoading, nodes.isEmpty {
                    Text("尚無圖說資料")
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else {
                    ForEach(nodes) { node in
                        if node.isFolder {
                            NavigationLink(value: node.id) {
                                DrawingFolderRowLabel(name: node.name)
                            }
                            .buttonStyle(.plain)
                        } else if node.isLeaf {
                            DrawingLeafCardView(projectId: projectId, node: node, vm: vm)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, bottomContentMargin)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

private struct DrawingFolderRowLabel: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.primary.opacity(0.95))
            Text(name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.75))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainer)
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
        }
        .accessibilityLabel("資料夾 \(name)")
    }
}

// MARK: - Leaf card

private struct DrawingLeafCardView: View {
    let projectId: String
    let node: DrawingNodeDTO
    @Bindable var vm: DrawingTreeViewModel
    @Environment(SessionManager.self) private var session

    @State private var quickLookSession: DrawingQuickLookSession?
    @State private var previewError: String?
    @State private var isPreparingPreview = false
    /// 讓「已預載」標籤在預載／清除後刷新。
    @State private var offlineStoreRefreshTick = 0

    private var revisions: [DrawingRevisionDTO] {
        vm.revisionsByNodeId[node.id] ?? []
    }

    private var displayFileName: String {
        node.latestFile?.fileName ?? node.name
    }

    private var isLatestFilePreloaded: Bool {
        _ = offlineStoreRefreshTick
        guard let fid = node.latestFile?.id, !fid.isEmpty else { return false }
        return FieldOfflineDrawingStore.hasFile(projectId: projectId, attachmentId: fid)
    }

    private var canOpenPreview: Bool {
        if let f = node.latestFile, !f.id.isEmpty { return true }
        if let list = vm.revisionsByNodeId[node.id], list.first != nil { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Task { await openLatestPreview() }
            } label: {
                cardInterior
            }
            .buttonStyle(.plain)
            .disabled(!canOpenPreview || isPreparingPreview)
        }
        .task(id: node.id) {
            await vm.loadRevisionsIfNeeded(projectId: projectId, nodeId: node.id, session: session)
        }
        .fullScreenCover(item: $quickLookSession) { session in
            FieldQuickLookPreviewSheet(fileURL: session.fileURL, title: session.title)
        }
        .alert("無法預覽", isPresented: Binding(
            get: { previewError != nil },
            set: { if !$0 { previewError = nil } }
        )) {
            Button("好", role: .cancel) { previewError = nil }
        } message: {
            Text(previewError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .fieldCacheStorageDidChange)) { _ in
            offlineStoreRefreshTick &+= 1
        }
    }

    private var cardInterior: some View {
        TacticalGlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TacticalGlassTheme.primary.opacity(0.95))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayFileName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text(versionSummary)
                            .font(.caption)
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    }
                    Spacer(minLength: 0)
                    if isPreparingPreview {
                        ProgressView()
                            .tint(TacticalGlassTheme.primary)
                    } else {
                        HStack(spacing: 8) {
                            if isLatestFilePreloaded {
                                Text("已預載")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(TacticalGlassTheme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background {
                                        Capsule()
                                            .fill(TacticalGlassTheme.primary.opacity(0.18))
                                    }
                            }
                            Image(systemName: "eye.circle.fill")
                                .font(.title3)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    metaRow(label: "上傳者", value: uploaderLine)
                    metaRow(label: "更新", value: updatedLine)
                    if let sz = sizeLine {
                        metaRow(label: "大小", value: sz)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("點兩下以預覽最新修訂")
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.88))
                .multilineTextAlignment(.leading)
        }
    }

    private var versionSummary: String {
        if revisions.isEmpty, vm.revisionsByNodeId[node.id] == nil {
            return "載入版本資訊中…"
        }
        if revisions.isEmpty {
            return "尚無修訂檔案"
        }
        let latest = revisions[0].createdAt.drawingFormattedDisplay()
        return "共 \(revisions.count) 版 · 最新 \(latest)"
    }

    private var uploaderLine: String {
        if revisions.isEmpty { return "—" }
        if let n = revisions[0].uploadedBy?.name, !n.isEmpty { return n }
        return "—"
    }

    private var updatedLine: String {
        if let r0 = revisions.first {
            return r0.createdAt.drawingFormattedDisplay()
        }
        if let c = node.latestFile?.createdAt {
            return c.drawingFormattedDisplay()
        }
        return "—"
    }

    private var sizeLine: String? {
        let n: Int?
        if let r0 = revisions.first {
            n = r0.fileSize
        } else if let f = node.latestFile {
            n = f.fileSize
        } else {
            n = nil
        }
        guard let n else { return nil }
        return formatBytes(n)
    }

    @MainActor
    private func openLatestPreview() async {
        previewError = nil
        let primaryAttachmentId: String?
        let name: String
        if let r0 = revisions.first {
            primaryAttachmentId = r0.id
            name = r0.fileName
        } else if let f = node.latestFile {
            primaryAttachmentId = f.id
            name = f.fileName
        } else {
            primaryAttachmentId = nil
            name = displayFileName
        }
        guard let primaryAttachmentId, !primaryAttachmentId.isEmpty else {
            previewError = "沒有可預覽的檔案"
            return
        }

        var candidateIds: [String] = []
        var seen = Set<String>()
        func appendId(_ id: String?) {
            guard let id, !id.isEmpty, !seen.contains(id) else { return }
            seen.insert(id)
            candidateIds.append(id)
        }
        appendId(revisions.first?.id)
        appendId(node.latestFile?.id)

        for aid in candidateIds {
            if let tempURL = FieldOfflineDrawingStore.temporaryURLForQuickLook(
                projectId: projectId,
                attachmentId: aid,
                displayFileName: name
            ) {
                quickLookSession = DrawingQuickLookSession(fileURL: tempURL, title: name)
                return
            }
        }

        isPreparingPreview = true
        defer { isPreparingPreview = false }
        do {
            let fileURL = try await session.withValidAccessToken { token in
                let fileURL = AppConfiguration.apiRootURL
                    .appendingPathComponent("files")
                    .appendingPathComponent(primaryAttachmentId)
                let data = try await APIService.fetchAuthorizedData(url: fileURL, token: token)
                let safe = name.replacingOccurrences(of: "/", with: "_")
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "_" + safe, isDirectory: false)
                try data.write(to: dest)
                return dest
            }
            quickLookSession = DrawingQuickLookSession(fileURL: fileURL, title: name)
        } catch let api as APIRequestError {
            previewError = api.localizedDescription
        } catch {
            previewError = error.localizedDescription
        }
    }

    private func formatBytes(_ n: Int) -> String {
        let b = ByteCountFormatter()
        b.countStyle = .file
        return b.string(fromByteCount: Int64(n))
    }
}

// MARK: - Date

private extension String {
    func drawingFormattedDisplay() -> String {
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: self) {
            return Self.drawingDisplay.string(from: d)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: self) {
            return Self.drawingDisplay.string(from: d)
        }
        return self
    }

    private static let drawingDisplay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
