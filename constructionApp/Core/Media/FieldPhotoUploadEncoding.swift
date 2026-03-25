//
//  FieldPhotoUploadEncoding.swift
//  constructionApp
//
//  上傳前統一為 JPEG，單檔上限 1MB（PMIS 規格）。
//

import PhotosUI
import SwiftUI
import UIKit

enum FieldPhotoUploadEncoding {
    /// 單張照片目標上限（位元組）。
    static let maxJPEGBytesForUpload: Int = 1_000_000

    /// 由 UIImage 產生不超過上限的 JPEG（遞減壓縮品質）。
    static func jpegDataForUpload(from image: UIImage) -> Data? {
        var quality: CGFloat = 0.92
        let minQuality: CGFloat = 0.35
        var data = image.jpegData(compressionQuality: quality)
        while let d = data, d.count > maxJPEGBytesForUpload, quality > minQuality + 0.01 {
            quality -= 0.07
            data = image.jpegData(compressionQuality: quality)
        }
        guard let final = data, final.count <= maxJPEGBytesForUpload else { return nil }
        return final
    }

    /// 相簿選取：支援 HEIC 等，轉成 UIImage 再壓 JPEG。
    @MainActor
    static func jpegDataForUpload(fromPickerItem item: PhotosPickerItem) async -> Data? {
        guard let raw = try? await item.loadTransferable(type: Data.self) else { return nil }
        if let ui = UIImage(data: raw) {
            return jpegDataForUpload(from: ui)
        }
        return nil
    }
}
