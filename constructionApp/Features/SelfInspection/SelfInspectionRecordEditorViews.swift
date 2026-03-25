//
//  SelfInspectionRecordEditorViews.swift
//  constructionApp
//
//  新增／編輯／檢視查驗紀錄（共用表單捲動區）。
//

import PhotosUI
import SwiftUI
import UIKit

private func selfInspectionCompletedCountForDetail(
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

private func selfInspectionFailItemCountForDetail(
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

// MARK: - Submit body

private func buildSelfInspectionSubmitBody(
    form: SelfInspectionRecordFormState,
    hub: SelfInspectionTemplateHubDTO,
    projectDisplayName: String,
    photoAttachmentIds: [String],
    submitError: inout String?
) -> SelfInspectionCreateRecordBody? {
    submitError = nil
    let allItemIds = hub.blocks.flatMap(\.items).map(\.id)
    for id in allItemIds {
        if form.itemResults[id] == nil {
            submitError = "請為每項檢查選擇通過或不通過"
            return nil
        }
    }
    let itemsEnc: [String: SelfInspectionItemFillEncodable] = Dictionary(
        uniqueKeysWithValues: allItemIds.map { id in
            (id, SelfInspectionItemFillEncodable(resultOptionId: form.itemResults[id]!))
        }
    )
    let headerEnc = SelfInspectionHeaderValuesEncodable(
        inspectionName: form.inspectionName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        projectName: projectDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        subProjectName: form.subProjectName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        subcontractor: form.subcontractor.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        inspectionLocation: form.inspectionLocation.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        inspectionDate: ymdString(from: form.inspectionDate).nilIfEmpty,
        timingOptionId: form.timingOptionId.isEmpty ? nil : form.timingOptionId
    )
    let photoEnc = photoAttachmentIds.isEmpty ? nil : photoAttachmentIds
    return SelfInspectionCreateRecordBody(
        filledPayload: SelfInspectionFilledPayloadEncodable(header: headerEnc, items: itemsEnc, photoAttachmentIds: photoEnc)
    )
}

private func selfInspectionUniqIdsPreservingOrder(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    out.reserveCapacity(ids.count)
    for id in ids {
        if seen.insert(id).inserted { out.append(id) }
    }
    return out
}

private func mimeForSelfInspectionImage(data: Data, fallbackExtension: String) -> String {
    if fallbackExtension.lowercased() == "png" { return "image/png" }
    if fallbackExtension.lowercased() == "heic" || fallbackExtension.lowercased() == "heif" {
        return "image/heic"
    }
    if data.count >= 2, data[0] == 0xFF, data[1] == 0xD8 { return "image/jpeg" }
    if data.count >= 8, data[0] == 0x89, data[1] == 0x50 { return "image/png" }
    return "image/jpeg"
}

private func uploadSelfInspectionPickerPhotos(
    projectId: String,
    token: String,
    items: [PhotosPickerItem]
) async throws -> [String] {
    var ids: [String] = []
    ids.reserveCapacity(items.count)
    for item in items {
        guard let data = try await item.loadTransferable(type: Data.self) else { continue }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        let fname = "photo.\(ext)"
        let mime = mimeForSelfInspectionImage(data: data, fallbackExtension: ext)
        let up = try await APIService.uploadProjectFile(
            baseURL: AppConfiguration.apiRootURL,
            token: token,
            projectId: projectId,
            fileData: data,
            fileName: fname,
            mimeType: mime,
            category: "self_inspection_photo"
        )
        ids.append(up.id)
    }
    return ids
}

// MARK: - Shared form scroll

private struct SelfInspectionRecordFormScrollContent: View {
    let hub: SelfInspectionTemplateHubDTO
    let projectDisplayName: String
    let accessToken: String
    @Bindable var form: SelfInspectionRecordFormState
    @Binding var submitError: String?

    private var remainingPhotoSlots: Int {
        max(0, 30 - form.committedPhotoIds.count - form.photoPickerItems.count)
    }

    var body: some View {
        let header = hub.template.headerConfig
        let (passId, failId) = passAndFailIds(from: header.resultLegendOptions)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let submitError, !submitError.isEmpty {
                    Text(submitError)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        tacticalLabeledField(
                            title: (header.inspectionNameLabel ?? "檢查名稱").uppercased(),
                            content: {
                                TextField("", text: $form.inspectionName)
                                    .font(.subheadline)
                                    .textInputAutocapitalization(.sentences)
                                    .foregroundStyle(.primary)
                            }
                        )

                        HStack(alignment: .top, spacing: 12) {
                            tacticalReadOnlyField(title: header.projectNameLabel.uppercased(), value: projectDisplayName)
                            tacticalLabeledField(title: header.subProjectLabel.uppercased(), content: {
                                TextField("", text: $form.subProjectName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            })
                        }

                        TacticalTextField(title: header.subcontractorLabel, text: $form.subcontractor)
                        TacticalTextField(title: header.inspectionLocationLabel, text: $form.inspectionLocation)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(header.inspectionDateLabel.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(1.2)
                            DatePicker("", selection: $form.inspectionDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(TacticalGlassTheme.primary)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.25))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TacticalGlassTheme.surfaceContainerLowest.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(header.timingSectionLabel.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .tracking(1.2)
                            timingPills(options: header.timingOptions)
                        }

                        Text(header.resultSectionLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            .padding(.top, 4)
                    }
                }

                let sortedBlocks = hub.blocks.sorted { $0.sortOrder < $1.sortOrder }
                ForEach(sortedBlocks) { block in
                    let items = block.items.sorted { $0.sortOrder < $1.sortOrder }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(block.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)

                        ForEach(items) { item in
                            checklistItemRow(
                                item: item,
                                passId: passId,
                                failId: failId,
                                selection: Binding(
                                    get: { form.itemResults[item.id] },
                                    set: { newVal in
                                        if let newVal {
                                            form.itemResults[item.id] = newVal
                                        } else {
                                            form.itemResults.removeValue(forKey: item.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("照片（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)

                        if !form.committedPhotoIds.isEmpty {
                            let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                            LazyVGrid(columns: cols, spacing: 10) {
                                ForEach(form.committedPhotoIds, id: \.self) { attId in
                                    ZStack(alignment: .topTrailing) {
                                        AuthenticatedRemoteImage(apiPath: "/api/v1/files/\(attId)", accessToken: accessToken)
                                            .aspectRatio(1, contentMode: .fill)
                                            .frame(minHeight: 88)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))
                                        Button {
                                            form.committedPhotoIds.removeAll { $0 == attId }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .black.opacity(0.55))
                                        }
                                        .padding(4)
                                        .accessibilityLabel("移除照片")
                                    }
                                }
                            }
                        }

                        if remainingPhotoSlots > 0 {
                            PhotosPicker(
                                selection: $form.photoPickerItems,
                                maxSelectionCount: min(12, remainingPhotoSlots),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("從相簿選擇", systemImage: "photo.on.rectangle.angled")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            }
                        } else {
                            Text("已達 30 張上限")
                                .font(.caption)
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }

                        Text("已選 \(form.committedPhotoIds.count + form.photoPickerItems.count)／30")
                            .font(.tacticalMonoFixed(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)

                        if !form.photoPreviewImages.isEmpty {
                            TacticalPhotoAlbumGrid(images: form.photoPreviewImages, columnCount: 3, spacing: 10)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: form.photoPickerFingerprint) { _, _ in
            Task { await form.refreshPhotoPreviews() }
        }
    }

    private func timingPills(options: [SelfInspectionOptionDTO]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options) { opt in
                    let selected = form.timingOptionId == opt.id
                    Button {
                        form.timingOptionId = opt.id
                    } label: {
                        Text(opt.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(
                                        selected
                                            ? TacticalGlassTheme.primary.opacity(0.22)
                                            : TacticalGlassTheme.surfaceContainerHighest.opacity(0.75)
                                    )
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        selected
                                            ? TacticalGlassTheme.primary.opacity(0.55)
                                            : TacticalGlassTheme.ghostBorder,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .foregroundStyle(selected ? TacticalGlassTheme.primary : TacticalGlassTheme.mutedLabel)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func checklistItemRow(
        item: SelfInspectionBlockItemDTO,
        passId: String,
        failId: String,
        selection: Binding<String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.categoryLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.primary)
                    Text(item.itemName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.standardText)
                        .font(.caption)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    resultToggle(
                        systemImage: "checkmark",
                        isOn: selection.wrappedValue == passId
                    ) {
                        selection.wrappedValue = passId
                    }
                    resultToggle(
                        systemImage: "xmark",
                        isOn: selection.wrappedValue == failId
                    ) {
                        selection.wrappedValue = failId
                    }
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
        }
    }

    private func resultToggle(systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 44, height: 44)
                .foregroundStyle(isOn ? TacticalGlassTheme.primary : TacticalGlassTheme.mutedLabel)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn ? TacticalGlassTheme.primary.opacity(0.2) : TacticalGlassTheme.surfaceContainerHighest.opacity(0.6))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isOn ? TacticalGlassTheme.primary.opacity(0.65) : TacticalGlassTheme.ghostBorder,
                            lineWidth: isOn ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func tacticalReadOnlyField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1.2)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.vertical, 4)
            Rectangle()
                .fill(TacticalGlassTheme.primary.opacity(0.2))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TacticalGlassTheme.surfaceContainerLowest.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))
    }

    private func tacticalLabeledField(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1.2)
            content()
                .padding(.vertical, 4)
            Rectangle()
                .fill(TacticalGlassTheme.primary.opacity(0.25))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TacticalGlassTheme.surfaceContainerLowest.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))
    }
}

// MARK: - Create

struct SelfInspectionCreateRecordView: View {
    let projectId: String
    let accessToken: String
    let templateId: String
    let projectDisplayName: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hub: SelfInspectionTemplateHubDTO?
    @State private var loadError: String?
    @State private var isLoadingHub = true
    @State private var form = SelfInspectionRecordFormState()
    @State private var isSubmitting = false
    @State private var submitError: String?

    var body: some View {
        Group {
            if isLoadingHub {
                ProgressView("載入樣板…")
                    .tint(TacticalGlassTheme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = loadError {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let hub {
                SelfInspectionRecordFormScrollContent(
                    hub: hub,
                    projectDisplayName: projectDisplayName,
                    accessToken: accessToken,
                    form: form,
                    submitError: $submitError
                )
            }
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("新增查驗")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(TacticalGlassTheme.primary)
                    } else {
                        Text("送出")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSubmitting || hub == nil)
                .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
        .task {
            await loadHub()
        }
    }

    private func loadHub() async {
        isLoadingHub = true
        loadError = nil
        defer { isLoadingHub = false }
        do {
            let h = try await APIService.getSelfInspectionTemplateHub(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                templateId: templateId
            )
            hub = h
            let opts = h.template.headerConfig.timingOptions
            if form.timingOptionId.isEmpty, let first = opts.first {
                form.timingOptionId = first.id
            }
        } catch let api as APIRequestError {
            loadError = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            loadError = error.localizedDescription
        }
    }

    private func submit() async {
        guard let hub else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let newIds: [String]
            if form.photoPickerItems.isEmpty {
                newIds = []
            } else {
                newIds = try await uploadSelfInspectionPickerPhotos(
                    projectId: projectId,
                    token: accessToken,
                    items: form.photoPickerItems
                )
            }
            let merged = selfInspectionUniqIdsPreservingOrder(form.committedPhotoIds + newIds)
            guard merged.count <= 30 else {
                submitError = "照片最多 30 張"
                return
            }
            guard let body = buildSelfInspectionSubmitBody(
                form: form,
                hub: hub,
                projectDisplayName: projectDisplayName,
                photoAttachmentIds: merged,
                submitError: &submitError
            ) else { return }

            _ = try await APIService.createSelfInspectionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                templateId: templateId,
                body: body
            )
            await onFinished()
            dismiss()
        } catch let api as APIRequestError {
            submitError = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            submitError = error.localizedDescription
        }
    }
}

// MARK: - Edit

struct SelfInspectionEditRecordView: View {
    let projectId: String
    let accessToken: String
    let templateId: String
    let recordId: String
    let projectDisplayName: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hub: SelfInspectionTemplateHubDTO?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var form = SelfInspectionRecordFormState()
    @State private var isSubmitting = false
    @State private var submitError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入紀錄…")
                    .tint(TacticalGlassTheme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = loadError {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let hub {
                SelfInspectionRecordFormScrollContent(
                    hub: hub,
                    projectDisplayName: projectDisplayName,
                    accessToken: accessToken,
                    form: form,
                    submitError: $submitError
                )
            }
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("編輯查驗")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundStyle(TacticalGlassTheme.mutedLabel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(TacticalGlassTheme.primary)
                    } else {
                        Text("儲存")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSubmitting || hub == nil)
                .foregroundStyle(TacticalGlassTheme.primary)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let detail = try await APIService.getSelfInspectionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                templateId: templateId,
                recordId: recordId
            )
            if let snap = detail.structureSnapshot {
                hub = snap.asHub
            } else {
                hub = try await APIService.getSelfInspectionTemplateHub(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    templateId: templateId
                )
            }
            form.apply(detail: detail)
            let opts = hub?.template.headerConfig.timingOptions ?? []
            if form.timingOptionId.isEmpty, let first = opts.first {
                form.timingOptionId = first.id
            }
        } catch let api as APIRequestError {
            loadError = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            loadError = error.localizedDescription
        }
    }

    private func submit() async {
        guard let hub else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let newIds: [String]
            if form.photoPickerItems.isEmpty {
                newIds = []
            } else {
                newIds = try await uploadSelfInspectionPickerPhotos(
                    projectId: projectId,
                    token: accessToken,
                    items: form.photoPickerItems
                )
            }
            let merged = selfInspectionUniqIdsPreservingOrder(form.committedPhotoIds + newIds)
            guard merged.count <= 30 else {
                submitError = "照片最多 30 張"
                return
            }
            guard let body = buildSelfInspectionSubmitBody(
                form: form,
                hub: hub,
                projectDisplayName: projectDisplayName,
                photoAttachmentIds: merged,
                submitError: &submitError
            ) else { return }

            _ = try await APIService.updateSelfInspectionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                templateId: templateId,
                recordId: recordId,
                body: body
            )
            await onFinished()
            dismiss()
        } catch let api as APIRequestError {
            submitError = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            submitError = error.localizedDescription
        }
    }
}

// MARK: - Detail (read-only)

struct SelfInspectionRecordDetailView: View {
    let projectId: String
    let templateId: String
    let recordId: String
    let accessToken: String
    let projectDisplayName: String
    var onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var record: SelfInspectionRecordDetailDTO?
    @State private var hub: SelfInspectionTemplateHubDTO?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var actionError: String?

    private var expectedItemIds: Set<String> {
        guard let hub else { return [] }
        return Set(hub.blocks.flatMap(\.items).map(\.id))
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入中…")
                    .tint(TacticalGlassTheme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = loadError {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(TacticalGlassTheme.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(24)
            } else if let record, let hub {
                detailScroll(record: record, hub: hub)
            }
        }
        .background(TacticalGlassTheme.surface)
        .navigationTitle("查驗紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TacticalGlassTheme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("編輯", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TacticalGlassTheme.primary)
                }
            }
        }
        .task {
            await load()
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                SelfInspectionEditRecordView(
                    projectId: projectId,
                    accessToken: accessToken,
                    templateId: templateId,
                    recordId: recordId,
                    projectDisplayName: projectDisplayName
                ) {
                    await load()
                    await onChanged()
                }
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(
            "確定刪除此筆查驗紀錄？此動作無法復原。",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) {
                Task { await deleteRecord() }
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func detailScroll(record: SelfInspectionRecordDetailDTO, hub: SelfInspectionTemplateHubDTO) -> some View {
        let header = hub.template.headerConfig
        let h = record.filledPayload?.header
        let ids = expectedItemIds
        let done = selfInspectionCompletedCountForDetail(expectedItemIds: ids, payload: record.filledPayload)
        let total = ids.count
        let ratio = total > 0 ? Double(done) / Double(total) : 0
        let isComplete = total > 0 && done >= total
        let (passId, failId) = passAndFailIds(from: header.resultLegendOptions)
        let failCount = passId != failId
            ? selfInspectionFailItemCountForDetail(expectedItemIds: ids, failId: failId, payload: record.filledPayload)
            : 0
        let hasFailItems = failCount > 0
        let displayProject =
            h?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? projectDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let actionError, !actionError.isEmpty {
                    Text(actionError)
                        .font(.subheadline)
                        .foregroundStyle(TacticalGlassTheme.tertiary)
                }

                if total == 0 {
                    Text("無法顯示檢查進度（缺少樣板結構）")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
                        }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("檢查進度 \(done)/\(total)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
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
                        if hasFailItems, isComplete {
                            Text("已全部填寫，惟仍有不通過項目，請留意改善。")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ProgressView(value: ratio)
                            .tint(hasFailItems ? TacticalGlassTheme.tertiary : TacticalGlassTheme.primary)
                    }
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .strokeBorder(
                                hasFailItems ? TacticalGlassTheme.tertiary.opacity(0.5) : TacticalGlassTheme.ghostBorder,
                                lineWidth: hasFailItems ? 1.5 : 1
                            )
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        detailLine(title: header.inspectionNameLabel ?? "檢查名稱", value: h?.inspectionName)
                        detailLine(title: header.projectNameLabel, value: displayProject)
                        detailLine(title: header.subProjectLabel, value: h?.subProjectName)
                        detailLine(title: header.subcontractorLabel, value: h?.subcontractor)
                        detailLine(title: header.inspectionLocationLabel, value: h?.inspectionLocation)
                        detailLine(title: header.inspectionDateLabel, value: h?.inspectionDate)
                        if let tid = h?.timingOptionId?.trimmingCharacters(in: .whitespacesAndNewlines), !tid.isEmpty {
                            let label = header.timingOptions.first { $0.id == tid }?.label ?? tid
                            detailLine(title: header.timingSectionLabel, value: label)
                        }
                    }
                }

                let sortedBlocks = hub.blocks.sorted { $0.sortOrder < $1.sortOrder }
                let options = header.resultLegendOptions
                ForEach(sortedBlocks) { block in
                    let items = block.items.sorted { $0.sortOrder < $1.sortOrder }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(block.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        ForEach(items) { item in
                            readOnlyChecklistRow(
                                item: item,
                                resultOptionId: record.filledPayload?.items?[item.id]?.resultOptionId,
                                legendOptions: options
                            )
                        }
                    }
                }

                if let photoIds = record.filledPayload?.photoAttachmentIds, !photoIds.isEmpty {
                    TacticalGlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("照片")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                            TacticalPhotoAlbumGrid(
                                source: .remote(
                                    photoIds.map { id in
                                        FileAttachmentDTO(
                                            id: id,
                                            fileName: "",
                                            fileSize: 0,
                                            mimeType: "image/jpeg",
                                            createdAt: "",
                                            url: "/api/v1/files/\(id)"
                                        )
                                    },
                                    accessToken: accessToken
                                ),
                                columnCount: 3,
                                spacing: 10
                            )
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func detailLine(title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1.0)
            Text(value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readOnlyChecklistRow(
        item: SelfInspectionBlockItemDTO,
        resultOptionId: String?,
        legendOptions: [SelfInspectionOptionDTO]
    ) -> some View {
        let rid = resultOptionId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let label = rid.flatMap { id in legendOptions.first { $0.id == id }?.label } ?? "—"
        let (passId, failId) = passAndFailIds(from: legendOptions)
        let isPass = rid == passId
        let isFail = rid == failId

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.categoryLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TacticalGlassTheme.primary)
                    Text(item.itemName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.standardText)
                        .font(.caption)
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(isPass ? TacticalGlassTheme.primary : TacticalGlassTheme.mutedLabel.opacity(0.35))
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(isFail ? TacticalGlassTheme.tertiary : TacticalGlassTheme.mutedLabel.opacity(0.35))
                    }
                    .font(.title3)
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(TacticalGlassTheme.surfaceContainerLow.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: 1)
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        actionError = nil
        defer { isLoading = false }
        do {
            let detail = try await APIService.getSelfInspectionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                templateId: templateId,
                recordId: recordId
            )
            record = detail
            if let snap = detail.structureSnapshot {
                hub = snap.asHub
            } else {
                hub = try await APIService.getSelfInspectionTemplateHub(
                    baseURL: AppConfiguration.apiRootURL,
                    token: accessToken,
                    projectId: projectId,
                    templateId: templateId
                )
            }
        } catch let api as APIRequestError {
            loadError = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            loadError = error.localizedDescription
        }
    }

    private func deleteRecord() async {
        actionError = nil
        do {
            try await APIService.deleteSelfInspectionRecord(
                baseURL: AppConfiguration.apiRootURL,
                token: accessToken,
                projectId: projectId,
                templateId: templateId,
                recordId: recordId
            )
            await onChanged()
            dismiss()
        } catch let api as APIRequestError {
            actionError = api.localizedDescription
        } catch {
            guard !error.isIgnorableTaskCancellation else { return }
            actionError = error.localizedDescription
        }
    }
}

// MARK: - Helpers

private func passAndFailIds(from options: [SelfInspectionOptionDTO]) -> (String, String) {
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

private func ymdString(from date: Date) -> String {
    let cal = Calendar.current
    let c = cal.dateComponents([.year, .month, .day], from: date)
    guard let y = c.year, let m = c.month, let d = c.day else { return "" }
    return String(format: "%04d-%02d-%02d", y, m, d)
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
