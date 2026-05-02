//
//  DrawingIPadBrowserView.swift
//  constructionApp
//
//  iPad 三欄式專用圖說瀏覽器：drill-down 模式（與 iPad 備忘錄／Files／Mail 一致），但點檔案後不開全螢幕，而是把預覽資訊寫入 `DrawingIPadSelection` reference 物件，由 IPadShellView observe 並在 detail 欄就地顯示 PDF。
//
//  跨 navigation push 邊界傳值：透過 view init 把 `selection` reference 物件一路明確傳遞，**不靠 environment**（environment 在 navigationDestination 內常因 closure value 重繪而 stale）。reference 永遠指向 IPadShellView 的同一個 @State 物件，mutation 經 @Observable 觸發 re-render。
//
//  iPhone 路徑 `DrawingManagementRootView` 完全不動，兩邊共享 model 層（DrawingTreeViewModel、DrawingNodeDTO、FieldOfflineDrawingStore）與 leaf 卡片視覺（DrawingLeafCardBody）。
//

import SwiftUI

// MARK: - Navigation destination modifier (root only)

private struct DrawingFolderDestinationIfRoot: ViewModifier {
    let isRoot: Bool
    let projectId: String
    @Bindable var vm: DrawingTreeViewModel
    @Bindable var selection: DrawingIPadSelection

    @Environment(\.fieldTheme) private var theme

    func body(content: Content) -> some View {
        if isRoot {
            content.navigationDestination(for: String.self) { folderId in
                if let folder = vm.node(byId: folderId), folder.isFolder {
                    DrawingIPadFolderView(
                        projectId: projectId,
                        nodes: folder.children ?? [],
                        vm: vm,
                        selection: selection
                    )
                    .navigationTitle(folder.name)
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    Text("找不到資料夾")
                        .font(.subheadline)
                        .foregroundStyle(theme.mutedLabel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Selection holder

/// iPad 圖說 detail 欄當前預覽的 selection。透過 view init 傳給 `DrawingIPadFolderView` 的所有層級，一路 reference 同一物件；點檔案 fetch URL 完成後寫入此物件，IPadShellView observe 後即時更新 detail 欄。
@MainActor
@Observable
final class DrawingIPadSelection {
    var url: URL?
    var title: String?
    /// 用於高亮列表中當前在 detail 欄顯示的卡片。
    var attachmentId: String?

    func reset() {
        url = nil
        title = nil
        attachmentId = nil
    }
}

// MARK: - Folder view (drill-down)

struct DrawingIPadFolderView: View {
    let projectId: String
    let nodes: [DrawingNodeDTO]
    @Bindable var vm: DrawingTreeViewModel
    @Bindable var selection: DrawingIPadSelection
    /// root 層級才顯示 vm 的 loading／空狀態；子層 push 過來時假設 root 已載入完成。
    var isRoot: Bool = false

    @Environment(\.fieldTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SessionManager.self) private var session

    @State private var loadingNodeId: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                /// root 層級顯示與 iPhone 一致的 chrome：模組大標題（ObsidianModuleHeaderView）。子層級已由 NavigationStack 提供 nav bar title，不需要重複大標題。
                if isRoot {
                    ObsidianModuleHeaderView(title: "圖說管理")
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                if isRoot, vm.isLoading, nodes.isEmpty {
                    ProgressView()
                        .tint(theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if isRoot, !vm.isLoading, nodes.isEmpty {
                    Text("尚無圖說資料")
                        .font(.subheadline)
                        .foregroundStyle(theme.mutedLabel)
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
                            leafButton(node)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        /// drill-down 子層 push 後 SwiftUI 預設背景白色，這裡顯式設為 surface 與 sidebar / root 一致。
        .background(theme.surface)
        .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        /// `navigationDestination(for: String.self)` 只在 NavigationStack root（isRoot == true）註冊一次，子層 push 過來時不再重複註冊；否則 SwiftUI runtime 會 warn「Only the destination declared closest to the root view of the stack will be used」並有效能影響（push 越深 warning 越多）。
        .modifier(DrawingFolderDestinationIfRoot(
            isRoot: isRoot,
            projectId: projectId,
            vm: vm,
            selection: selection
        ))
        .alert("無法預覽", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Leaf row

    private func leafButton(_ node: DrawingNodeDTO) -> some View {
        let isLoading = loadingNodeId == node.id
        let isSelected = isSelectedLeaf(node)
        return Button {
            Task { await openFile(node) }
        } label: {
            DrawingLeafCardBody(
                node: node,
                revisions: vm.revisionsByNodeId[node.id] ?? [],
                revisionsLoaded: vm.revisionsByNodeId[node.id] != nil,
                isLatestFilePreloaded: isPreloaded(node),
                isPreparingPreview: isLoading
            )
            .overlay {
                /// iPad 三欄式：當前在 detail 欄顯示的卡片加 12pt 圓角主色 stroke。
                if isSelected {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .stroke(theme.primary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .task(id: node.id) {
            await vm.loadRevisionsIfNeeded(projectId: projectId, nodeId: node.id, session: session)
        }
    }

    private func isSelectedLeaf(_ node: DrawingNodeDTO) -> Bool {
        guard let target = selection.attachmentId else { return false }
        if let r0 = vm.revisionsByNodeId[node.id]?.first, r0.id == target { return true }
        if let f = node.latestFile, f.id == target { return true }
        return false
    }

    private func isPreloaded(_ node: DrawingNodeDTO) -> Bool {
        guard let fid = node.latestFile?.id, !fid.isEmpty else { return false }
        return FieldOfflineDrawingStore.hasFile(projectId: projectId, attachmentId: fid)
    }

    // MARK: - Open file (fetch URL → write selection)

    @MainActor
    private func openFile(_ node: DrawingNodeDTO) async {
        await vm.loadRevisionsIfNeeded(projectId: projectId, nodeId: node.id, session: session)
        let revisions = vm.revisionsByNodeId[node.id] ?? []

        let primaryAttachmentId: String?
        let displayName: String
        if let r0 = revisions.first {
            primaryAttachmentId = r0.id
            displayName = r0.fileName
        } else if let f = node.latestFile {
            primaryAttachmentId = f.id
            displayName = f.fileName
        } else {
            primaryAttachmentId = nil
            displayName = node.name
        }
        guard let primaryAttachmentId, !primaryAttachmentId.isEmpty else {
            errorMessage = "沒有可預覽的檔案"
            return
        }

        // 1. 試離線快取
        var candidateIds: [String] = []
        var seen = Set<String>()
        for id in [revisions.first?.id, node.latestFile?.id] {
            guard let id, !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            candidateIds.append(id)
        }
        for aid in candidateIds {
            if let tempURL = FieldOfflineDrawingStore.temporaryURLForQuickLook(
                projectId: projectId,
                attachmentId: aid,
                displayFileName: displayName
            ) {
                writeSelection(url: tempURL, title: displayName, attachmentId: aid)
                return
            }
        }

        // 2. 線上 fetch
        loadingNodeId = node.id
        defer { loadingNodeId = nil }
        do {
            let url = try await session.withValidAccessToken { token in
                let fileURL = AppConfiguration.apiRootURL
                    .appendingPathComponent("files")
                    .appendingPathComponent(primaryAttachmentId)
                let data = try await APIService.fetchAuthorizedData(url: fileURL, token: token)
                let safe = displayName.replacingOccurrences(of: "/", with: "_")
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "_" + safe, isDirectory: false)
                try data.write(to: dest)
                return dest
            }
            writeSelection(url: url, title: displayName, attachmentId: primaryAttachmentId)
        } catch let api as APIRequestError {
            errorMessage = api.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func writeSelection(url: URL, title: String, attachmentId: String) {
        selection.url = url
        selection.title = title
        selection.attachmentId = attachmentId
    }
}
