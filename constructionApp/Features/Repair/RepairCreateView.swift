//
//  RepairCreateView.swift
//  constructionApp
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class RepairCreateViewModel {
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
    var photoPickerItems: [PhotosPickerItem] = []
    var photoPreviewImages: [UIImage] = []
    var extraFiles: [(data: Data, name: String, mime: String)] = []
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

        isSubmitting = true
        defer { isSubmitting = false }

        var photoIds: [String] = []
        var fileIds: [String] = []

        do {
            for item in photoPickerItems {
                guard photoIds.count < 30 else { break }
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fname = "photo.\(ext)"
                let mime = mimeForImage(data: data, fallbackExtension: ext)
                let up = try await APIService.uploadProjectFile(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    fileData: data,
                    fileName: fname,
                    mimeType: mime,
                    category: "repair_photo"
                )
                photoIds.append(up.id)
            }
            guard photoIds.count <= 30 else {
                errorMessage = "照片最多 30 張"
                return false
            }

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
                fileIds.append(up.id)
            }

            let body = CreateRepairRequestBody(
                customerName: name,
                contactPhone: phone,
                repairContent: content,
                problemCategory: problemCategory,
                isSecondRepair: isSecondRepair,
                status: status,
                unitLabel: unitLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                remarks: remarks.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                deliveryDate: deliveryDateYMD.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                repairDate: repairDateYMD.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                photoAttachmentIds: photoIds.isEmpty ? nil : photoIds,
                fileAttachmentIds: fileIds.isEmpty ? nil : fileIds
            )

            _ = try await APIService.createRepairRequest(
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

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

struct RepairCreateView: View {
    let projectId: String
    let accessToken: String
    var onFinished: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var createModel = RepairCreateViewModel()
    @State private var showDocImporter = false

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
                        TacticalTextField(title: "客戶姓名", text: $vm.customerName, contentType: .name)
                        TacticalTextField(title: "聯絡電話", text: $vm.contactPhone, keyboard: .phonePad, contentType: .telephoneNumber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("報修內容".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                            TextField("", text: $vm.repairContent, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(4 ... 8)
                                .textInputAutocapitalization(.sentences)
                                .padding(.vertical, 4)
                            Rectangle()
                                .fill(TacticalGlassTheme.primary.opacity(0.28))
                                .frame(height: 1)
                        }
                        TacticalTextField(title: "戶別（選填）", text: $vm.unitLabel)

                        categoryPicker

                        VStack(alignment: .leading, spacing: 4) {
                            Text("狀態".uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $vm.status) {
                                Text("進行中").tag("in_progress")
                                Text("已完成").tag("completed")
                            }
                            .pickerStyle(.segmented)
                            .tint(TacticalGlassTheme.primary)
                        }

                        Toggle(isOn: $vm.isSecondRepair) {
                            Text("是否二次維修")
                                .font(.subheadline)
                        }
                        .tint(TacticalGlassTheme.primary)

                        TacticalTextField(title: "交付日期 YYYY-MM-DD（選填）", text: $vm.deliveryDateYMD)
                        TacticalTextField(title: "修繕完成日 YYYY-MM-DD（選填）", text: $vm.repairDateYMD)
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("備註（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        TextField("", text: $vm.remarks, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(2 ... 4)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 4)
                    }
                }

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("照片（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
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

                TacticalGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("附件（選填）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        Button {
                            showDocImporter = true
                        } label: {
                            Label("加入檔案", systemImage: "paperclip")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                        ForEach(Array(createModel.extraFiles.enumerated()), id: \.offset) { _, f in
                            Text(f.name)
                                .font(.tacticalMonoFixed(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
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
                        Text("建立報修")
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
        .navigationTitle("新增報修")
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
        .fileImporter(
            isPresented: $showDocImporter,
            allowedContentTypes: [.pdf, .plainText, .data, .image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                for url in urls {
                    let got = url.startAccessingSecurityScopedResource()
                    defer {
                        if got { url.stopAccessingSecurityScopedResource() }
                    }
                    guard let data = try? Data(contentsOf: url) else { continue }
                    let name = url.lastPathComponent
                    let mime = mimeTypeForFileURL(url)
                    createModel.extraFiles.append((data, name, mime))
                }
            case .failure:
                break
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("問題類別".uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Menu {
                ForEach(RepairConstants.problemCategories, id: \.self) { cat in
                    Button(cat) { createModel.problemCategory = cat }
                }
            } label: {
                HStack {
                    Text(createModel.problemCategory.isEmpty ? "請選擇" : createModel.problemCategory)
                        .font(.subheadline)
                        .foregroundStyle(createModel.problemCategory.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TacticalGlassTheme.mutedLabel)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(TacticalGlassTheme.surfaceContainerLowest.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))
            }
            Rectangle()
                .fill(TacticalGlassTheme.primary.opacity(0.28))
                .frame(height: 1)
        }
    }

    private func mimeTypeForFileURL(_ url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}
