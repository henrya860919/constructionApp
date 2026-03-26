//
//  DrawingOfflinePreloadSheet.swift
//  constructionApp
//

import SwiftUI

@MainActor
@Observable
final class DrawingOfflinePreloadController {
    var isRunning = false
    var completed = 0
    var total = 0
    var currentLabel: String = ""
    var lastMessage: String?
    var stoppedByQuota = false
    private(set) var resumeFromIndex = 0

    /// (nodeId, attachmentId, displayName)
    static func preloadTargets(from roots: [DrawingNodeDTO]) -> [(String, String, String)] {
        var out: [(String, String, String)] = []
        func walk(_ nodes: [DrawingNodeDTO]) {
            for n in nodes {
                if n.isFolder, let ch = n.children {
                    walk(ch)
                } else if n.isLeaf, let f = n.latestFile, !f.id.isEmpty {
                    out.append((n.id, f.id, f.fileName))
                }
            }
        }
        walk(roots)
        return out
    }

    func resetForNewRun(tree: [DrawingNodeDTO]) {
        resumeFromIndex = 0
        lastMessage = nil
        stoppedByQuota = false
        let t = Self.preloadTargets(from: tree)
        total = t.count
        completed = 0
        currentLabel = ""
    }

    func run(projectId: String, tree: [DrawingNodeDTO], session: SessionManager) async {
        let targets = Self.preloadTargets(from: tree)
        total = targets.count
        guard !targets.isEmpty else {
            lastMessage = "沒有可預載的圖說檔案（樹狀中尚無已上傳之最新檔）。"
            return
        }

        isRunning = true
        if resumeFromIndex == 0 {
            lastMessage = nil
        }
        stoppedByQuota = false
        defer {
            isRunning = false
            currentLabel = ""
        }

        for i in resumeFromIndex ..< targets.count {
            let (nodeId, attachmentId, name) = targets[i]
            currentLabel = name

            if FieldOfflineDrawingStore.hasFile(projectId: projectId, attachmentId: attachmentId) {
                completed = i + 1
                continue
            }

            do {
                let data = try await session.withValidAccessToken { token in
                    let url = AppConfiguration.apiRootURL
                        .appendingPathComponent("files")
                        .appendingPathComponent(attachmentId)
                    return try await APIService.fetchAuthorizedData(url: url, token: token)
                }
                do {
                    try FieldOfflineDrawingStore.save(
                        projectId: projectId,
                        nodeId: nodeId,
                        attachmentId: attachmentId,
                        fileName: name,
                        data: data
                    )
                } catch let q as FieldOfflineDrawingStoreError {
                    if case .overQuota = q {
                        stoppedByQuota = true
                        resumeFromIndex = i
                        lastMessage = q.localizedDescription
                            + "（進度 \(i)／\(targets.count)）"
                        completed = i
                        return
                    }
                    throw q
                }
            } catch {
                guard !error.isIgnorableTaskCancellation else { return }
                lastMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                resumeFromIndex = i
                completed = i
                return
            }
            completed = i + 1
        }

        resumeFromIndex = 0
        if lastMessage == nil, !stoppedByQuota {
            lastMessage = "預載完成（\(targets.count) 個檔案）。"
        }
    }
}

struct DrawingOfflinePreloadSheet: View {
    let projectId: String
    let tree: [DrawingNodeDTO]
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session

    @State private var controller = DrawingOfflinePreloadController()

    private var vaultUsed: Int64 { FieldOfflineDrawingStore.totalBytes() }
    private var vaultBudget: Int64 { FieldOfflineDrawingStore.vaultBudgetBytes() }
    private var vaultAvail: Int64 { FieldOfflineDrawingStore.availableBytes() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("離線圖說空間")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(0.8)
                            Text(
                                "\(FieldByteCountFormatter.megabytesString(vaultUsed))"
                                    + " / \(FieldByteCountFormatter.megabytesString(vaultBudget))"
                            )
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            Text("尚可約 \(FieldByteCountFormatter.megabytesString(vaultAvail)) · 與列表圖片／網路快取（120MB）分開計算")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("將下載本專案圖說樹狀中每個項目的最新檔（與線上預覽相同來源），供離線時 Quick Look。空間不足時須先釋出後再繼續。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    if controller.total > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(
                                value: Double(controller.completed),
                                total: Double(max(controller.total, 1))
                            )
                            .tint(TacticalGlassTheme.primary)
                            Text("進度 \(controller.completed)／\(controller.total)")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            if !controller.currentLabel.isEmpty {
                                Text(controller.currentLabel)
                                    .font(.caption)
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                    .lineLimit(2)
                            }
                        }
                    }

                    if let msg = controller.lastMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(controller.stoppedByQuota ? TacticalGlassTheme.tertiary : TacticalGlassTheme.mutedLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { @MainActor in
                                guard !controller.isRunning else { return }
                                let targets = DrawingOfflinePreloadController.preloadTargets(from: tree)
                                if targets.isEmpty {
                                    controller.lastMessage = "沒有可預載的圖說檔案。"
                                    controller.total = 0
                                    return
                                }
                                if controller.resumeFromIndex == 0,
                                   controller.completed == 0 || controller.completed >= controller.total {
                                    controller.resetForNewRun(tree: tree)
                                }
                                await controller.run(projectId: projectId, tree: tree, session: session)
                            }
                        } label: {
                            if controller.isRunning {
                                ProgressView()
                                    .tint(TacticalGlassTheme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            } else {
                                Text(primaryButtonTitle)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                        }
                        .buttonStyle(TacticalPrimaryButtonStyle())
                        .disabled(tree.isEmpty || controller.isRunning)

                        if controller.stoppedByQuota {
                            Text("請至「設定」→「儲存空間」釋出離線圖說預載後，再點「繼續下載」。")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
            }
            .background(TacticalGlassTheme.surface)
            .navigationTitle("預先下載離線圖說")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                    .foregroundStyle(TacticalGlassTheme.primary)
                }
            }
            .onAppear {
                let n = DrawingOfflinePreloadController.preloadTargets(from: tree).count
                if controller.total == 0 { controller.total = n }
            }
        }
    }

    private var primaryButtonTitle: String {
        if controller.resumeFromIndex > 0, controller.completed < controller.total {
            "繼續下載"
        } else if controller.completed > 0, controller.completed >= controller.total {
            "重新預載此專案圖說"
        } else {
            "開始預載此專案圖說"
        }
    }
}
