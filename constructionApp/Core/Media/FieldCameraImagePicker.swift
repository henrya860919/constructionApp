//
//  FieldCameraImagePicker.swift
//  constructionApp
//
//  相機拍照（UIImagePickerController）＋與 PhotosPicker 並列的相簿／拍照按鈕。
//

import PhotosUI
import SwiftUI
import UIKit

enum FieldCameraCapture {
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

enum FieldCameraImageEncoding {
    /// 壓成 JPEG 供上傳與預覽（與相簿選圖路徑一致）。
    static func jpegData(from image: UIImage, quality: CGFloat = 0.88) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}

struct FieldCameraImagePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FieldCameraImagePicker

        init(_ parent: FieldCameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCapture(img)
            }
            parent.isPresented = false
        }
    }
}

/// 相簿（PhotosPicker）＋拍照並列；無相機時僅顯示相簿。
struct FieldPhotoLibraryAndCameraButtons: View {
    @Binding var photoPickerItems: [PhotosPickerItem]
    var maxPickerSelection: Int
    var remainingSlots: Int
    @Binding var showCamera: Bool
    /// 相簿按鈕標題（例：從相簿新增／從相簿選擇）
    var photoLibraryTitle: String
    var photoLibrarySystemImage: String = "photo.on.rectangle.angled"

    var body: some View {
        Group {
            if remainingSlots > 0 {
                HStack(spacing: 20) {
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: maxPickerSelection,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(photoLibraryTitle, systemImage: photoLibrarySystemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TacticalGlassTheme.mutedLabel)
                    }

                    if FieldCameraCapture.isCameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("拍照", systemImage: "camera.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                        }
                    }
                }
            }
        }
    }
}
