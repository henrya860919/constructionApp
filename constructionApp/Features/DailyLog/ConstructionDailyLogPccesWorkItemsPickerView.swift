//
//  ConstructionDailyLogPccesWorkItemsPickerView.swift
//  constructionApp
//
//  與網頁施工日誌「帶出核定工項」相同資料源：pcces-work-items。
//  目錄列僅供鑽入；僅 isStructuralLeaf 可勾選。此畫面不填本日完成量。
//

import SwiftUI

private func rowsDirectChildren(
    parentKey: Int?,
    in rows: [ConstructionDailyLogPccesPickerRowDTO]
) -> [ConstructionDailyLogPccesPickerRowDTO] {
    rows.filter { $0.parentItemKey == parentKey }
        .sorted { lhs, rhs in
            if lhs.itemKey != rhs.itemKey { return lhs.itemKey < rhs.itemKey }
            return lhs.itemNo.localizedStandardCompare(rhs.itemNo) == .orderedAscending
        }
}

struct ConstructionDailyLogPccesWorkItemsPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session

    let projectId: String
    /// `yyyy-MM-dd`，與後端 logDate 一致。
    let logDate: String
    @Binding var workItems: [FieldDailyLogWorkItem]

    @State private var rows: [ConstructionDailyLogPccesPickerRowDTO] = []
    @State private var pccesImport: ConstructionDailyLogPccesPickerImportDTO?
    @State private var loadState: LoadState = .idle

    private enum LoadState: Equatable {
        case idle
        case loading
        case failed(String)
        case ready
    }

    var body: some View {
        Group {
            switch loadState {
            case .idle, .loading:
                ProgressView("載入核定工項…")
                    .tint(theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(msg):
                VStack(spacing: 12) {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(theme.onSurface)
                        .multilineTextAlignment(.center)
                    Button("重試") {
                        Task { await loadRows() }
                    }
                    .buttonStyle(TacticalSecondaryButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                let roots = rowsDirectChildren(parentKey: nil, in: rows)
                if pccesImport == nil || roots.isEmpty || !rows.contains(where: { $0.isStructuralLeaf }) {
                    Text(
                        "專案尚無已核定之 PCCES 版本，或該版無可填寫之明細工項。請至「PCCES 匯入紀錄」核定其中一版後再試。"
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.mutedLabel)
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ConstructionDailyLogPccesWorkItemsLevelView(
                        allRows: rows,
                        parentItemKey: nil,
                        workItems: $workItems
                    )
                }
            }
        }
        .background(theme.surface)
        .navigationTitle("選擇工項")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .task {
            await loadRows()
        }
    }

    @MainActor
    private func loadRows() async {
        loadState = .loading
        do {
            let data = try await session.withValidAccessToken { token in
                try await APIService.fetchConstructionDailyLogPccesWorkItems(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    logDate: logDate
                )
            }
            rows = data.rows
            pccesImport = data.pccesImport
            loadState = .ready
        } catch let e as APIRequestError {
            switch e {
            case let .httpStatus(code, message):
                if code == 403 {
                    loadState = .failed("無權限讀取施工日誌或 PCCES 工項，請洽管理員。")
                } else {
                    loadState = .failed(message ?? "載入失敗（\(code)）")
                }
            default:
                loadState = .failed("無法連線或載入失敗。")
            }
        } catch is FieldSessionAuthError {
            loadState = .failed("請先登入後再選擇工項。")
        } catch {
            loadState = .failed("載入失敗。")
        }
    }
}

// MARK: - 階層列表

struct ConstructionDailyLogPccesWorkItemsLevelView: View {
    @Environment(\.fieldTheme) private var theme

    let allRows: [ConstructionDailyLogPccesPickerRowDTO]
    let parentItemKey: Int?
    @Binding var workItems: [FieldDailyLogWorkItem]

    private var nodes: [ConstructionDailyLogPccesPickerRowDTO] {
        rowsDirectChildren(parentKey: parentItemKey, in: allRows)
    }

    var body: some View {
        List {
            ForEach(nodes) { node in
                if node.isSelectableLeaf {
                    leafRow(node)
                } else {
                    NavigationLink {
                        ConstructionDailyLogPccesWorkItemsLevelView(
                            allRows: allRows,
                            parentItemKey: node.itemKey,
                            workItems: $workItems
                        )
                        .navigationTitle(node.workItemName)
                    } label: {
                        parentRowLabel(node)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.surface)
    }

    /// 圖示、項次、項目、單位同一列；文字過長可換行；`HStack(alignment: .center)` 讓各欄對整列垂直置中。
    @ViewBuilder
    private func pccesPickerRow<Icon: View>(
        icon: Icon,
        itemNo: String,
        workItemName: String,
        unit: String
    ) -> some View {
        let unitDisplay = unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : unit
        HStack(alignment: .center, spacing: 10) {
            icon
                .frame(width: 28, alignment: .center)
            Text(itemNo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: true, vertical: true)
            Text(workItemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.onSurface)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text(unitDisplay)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.mutedLabel.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func parentRowLabel(_ node: ConstructionDailyLogPccesPickerRowDTO) -> some View {
        pccesPickerRow(
            icon: Image(systemName: "folder.fill")
                .font(.body)
                .foregroundStyle(theme.mutedLabel),
            itemNo: node.itemNo,
            workItemName: node.workItemName,
            unit: node.unit
        )
        .accessibilityLabel("\(node.itemNo) \(node.workItemName)，目錄，進入子項")
    }

    private func leafRow(_ node: ConstructionDailyLogPccesPickerRowDTO) -> some View {
        let selected = workItems.contains { $0.pccesItemId == node.pccesItemId }
        return Button {
            toggleLeaf(node)
        } label: {
            pccesPickerRow(
                icon: Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? theme.primary : theme.mutedLabel),
                itemNo: node.itemNo,
                workItemName: node.workItemName,
                unit: node.unit
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(node.itemNo) \(node.workItemName)，單位 \(node.unit)，\(selected ? "已選" : "未選")")
    }

    private func toggleLeaf(_ node: ConstructionDailyLogPccesPickerRowDTO) {
        guard node.isSelectableLeaf else { return }
        if let idx = workItems.firstIndex(where: { $0.pccesItemId == node.pccesItemId }) {
            workItems.remove(at: idx)
        } else {
            workItems.append(
                FieldDailyLogWorkItem(
                    pccesItemId: node.pccesItemId,
                    itemNo: node.itemNo,
                    workItemName: node.workItemName,
                    unit: node.unit,
                    contractQty: node.contractQty,
                    unitPrice: node.unitPrice,
                    pccesItemKind: node.itemKind,
                    dailyQty: ""
                )
            )
        }
    }
}
