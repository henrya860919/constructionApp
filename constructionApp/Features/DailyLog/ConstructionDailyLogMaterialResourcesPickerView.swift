//
//  ConstructionDailyLogMaterialResourcesPickerView.swift
//  constructionApp
//
//  與網頁「從資源庫填寫材料」相同資料源：construction-daily-logs/defaults。
//  此頁只決定要納入哪些材料；本日使用量與備註回編輯頁填寫。
//

import SwiftUI

struct ConstructionDailyLogMaterialResourcesPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session

    let projectId: String
    let logDate: String
    @Binding var materials: [FieldDailyLogMaterialRow]

    @State private var resources: [ConstructionDailyLogMaterialResourceDTO] = []
    @State private var priors: [String: String] = [:]
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
                ProgressView("載入資源庫材料…")
                    .tint(theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(msg):
                VStack(spacing: 12) {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(theme.onSurface)
                        .multilineTextAlignment(.center)
                    Button("重試") {
                        Task { await loadDefaults() }
                    }
                    .buttonStyle(TacticalSecondaryButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                if resources.isEmpty {
                    Text("資源庫尚無「材料」類別項目，請至專案管理資源庫新增後再試。")
                        .font(.subheadline)
                        .foregroundStyle(theme.mutedLabel)
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("點選圓圈選擇要列入本日日誌的材料，返回編輯頁後再填寫本日使用量與備註（與選擇工項相同）。")
                                .font(.footnote)
                                .foregroundStyle(theme.mutedLabel)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        ForEach(resources, id: \.id) { r in
                            materialResourceSelectableRow(r)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(theme.surface)
                }
            }
        }
        .background(theme.surface)
        .navigationTitle("選擇材料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .task {
            await loadDefaults()
        }
    }

    @ViewBuilder
    private func materialResourceSelectableRow(_ r: ConstructionDailyLogMaterialResourceDTO) -> some View {
        let selected = materials.contains { $0.projectResourceId == r.id }
        let unitDisplay = r.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : r.unit
        Button {
            toggleMaterialResource(r)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? theme.primary : theme.mutedLabel)
                Text(r.name)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(r.name)，單位 \(unitDisplay)，\(selected ? "已選" : "未選")")
    }

    private func toggleMaterialResource(_ r: ConstructionDailyLogMaterialResourceDTO) {
        var next = materials
        if let idx = next.firstIndex(where: { $0.projectResourceId == r.id }) {
            next.remove(at: idx)
        } else {
            let prior = priors[r.id] ?? "0"
            next.append(
                FieldDailyLogMaterialRow.fromProjectResource(
                    resourceId: r.id,
                    name: r.name,
                    unit: r.unit,
                    priorQty: prior
                )
            )
        }
        materials = next
    }

    @MainActor
    private func loadDefaults() async {
        loadState = .loading
        do {
            let defs = try await session.withValidAccessToken { token in
                try await APIService.fetchConstructionDailyLogFormDefaults(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    logDate: logDate,
                    excludeLogId: nil
                )
            }
            resources = defs.materialResources
            priors = defs.materialResourcePriors
            loadState = .ready
        } catch let e as APIRequestError {
            switch e {
            case let .httpStatus(code, message):
                if code == 403 {
                    loadState = .failed("無權限讀取施工日誌或資源庫材料。")
                } else {
                    loadState = .failed(message ?? "載入失敗（\(code)）")
                }
            default:
                loadState = .failed("無法連線或載入失敗。")
            }
        } catch is FieldSessionAuthError {
            loadState = .failed("請先登入後再選擇材料。")
        } catch {
            loadState = .failed("載入失敗。")
        }
    }
}
