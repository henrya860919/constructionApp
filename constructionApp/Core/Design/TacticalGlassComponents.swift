//
//  TacticalGlassComponents.swift
//  constructionApp
//

import PhotosUI
import SwiftUI
import UIKit

// MARK: - Typography

extension Font {
    /// Instrument-style numerics (SF Mono); IDs, timestamps, metrics.
    static func tacticalMono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }

    static func tacticalMonoFixed(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct TacticalHeadlineModifier: ViewModifier {
    var size: CGFloat
    var weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: .default))
            .kerning(TacticalGlassTheme.headlineKerning(forSize: size))
    }
}

extension View {
    func tacticalDisplay(_ size: CGFloat = 34, weight: Font.Weight = .bold) -> some View {
        modifier(TacticalHeadlineModifier(size: size, weight: weight))
    }

    func tacticalTitle(_ size: CGFloat = 22, weight: Font.Weight = .semibold) -> some View {
        modifier(TacticalHeadlineModifier(size: size, weight: weight))
    }
}

// MARK: - Tonal card (no structural 1px rules — layering only)

struct TacticalGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = TacticalGlassTheme.cornerRadius
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        elevated
                            ? TacticalGlassTheme.surfaceContainerHighest
                            : TacticalGlassTheme.surfaceContainer
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Buttons

struct TacticalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(TacticalGlassTheme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.primaryGradient())
                    .opacity(configuration.isPressed ? 0.88 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct TacticalSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(TacticalGlassTheme.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.surfaceContainerHighest.opacity(configuration.isPressed ? 0.95 : 0.88))
            }
            .overlay {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .strokeBorder(TacticalGlassTheme.outlineVariant.opacity(0.2), lineWidth: 1)
            }
    }
}

// MARK: - FAB — rounded square + gradient (Obsidian spec)

struct ObsidianSquareFAB: View {
    var systemImage: String = "plus"
    var accessibilityLabel: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.92))
            .frame(width: 56, height: 56)
            .background {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.primaryGradient())
            }
            .shadow(color: TacticalGlassTheme.ambientShadow, radius: 40, x: 0, y: 12)
            .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - FAB fades while list / scroll moves

private struct FieldFABScrollIdleModifier: ViewModifier {
    @Binding var scrollIdle: Bool
    @State private var resetTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldY, newY in
                guard abs(newY - oldY) > 0.25 else { return }
                scrollIdle = false
                resetTask?.cancel()
                resetTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled else { return }
                    scrollIdle = true
                }
            }
    }
}

extension View {
    /// 捲動時將 `scrollIdle` 設為 `false`；停止約 220ms 後設回 `true`（外層 FAB 用 `opacity(scrollIdle ? 1 : 0)`）。
    func fieldFABScrollIdleTracking(_ scrollIdle: Binding<Bool>) -> some View {
        modifier(FieldFABScrollIdleModifier(scrollIdle: scrollIdle))
    }
}

// MARK: - Underline focus field — primary indicator (not blue)

struct TacticalTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var isSecure: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1.2)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                        .textContentType(contentType ?? .password)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(contentType)
                }
            }
            .focused($focused)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.vertical, 4)

            Rectangle()
                .fill(focused ? TacticalGlassTheme.primary : TacticalGlassTheme.primary.opacity(0.25))
                .frame(height: focused ? 2 : 1)
                .animation(.easeOut(duration: 0.2), value: focused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TacticalGlassTheme.surfaceContainerLowest.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous))
    }
}

// MARK: - Photo album grid (square cells + full-screen preview)

enum TacticalPhotoAlbumSource {
    case remote([FileAttachmentDTO], accessToken: String)
    case local([UIImage])

    fileprivate var count: Int {
        switch self {
        case .remote(let photos, _): photos.count
        case .local(let images): images.count
        }
    }
}

private struct AlbumGridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let n = nextValue()
        if n > 0 { value = n }
    }
}

private struct PhotoPreviewSession: Identifiable {
    let id = UUID()
    let startIndex: Int
}

/// 相簿式方格（固定正方形、`scaledToFill` 裁切），點擊以全螢幕左右滑檢視。遠端／本機共用此元件。
struct TacticalPhotoAlbumGrid: View {
    let source: TacticalPhotoAlbumSource
    var columnCount: Int = 3
    var spacing: CGFloat = 10
    var cornerRadius: CGFloat = TacticalGlassTheme.cornerRadius

    @State private var measuredContainerWidth: CGFloat = 0
    @State private var previewSession: PhotoPreviewSession?

    private var cols: Int { max(1, min(columnCount, 6)) }
    private var itemCount: Int { source.count }

    private var layoutWidth: CGFloat {
        if measuredContainerWidth > 1 { return measuredContainerWidth }
        return max(120, UIScreen.main.bounds.width - 64)
    }

    init(source: TacticalPhotoAlbumSource, columnCount: Int = 3, spacing: CGFloat = 10, cornerRadius: CGFloat = TacticalGlassTheme.cornerRadius) {
        self.source = source
        self.columnCount = columnCount
        self.spacing = spacing
        self.cornerRadius = cornerRadius
    }

    init(photos: [FileAttachmentDTO], accessToken: String, columnCount: Int = 3, spacing: CGFloat = 10, cornerRadius: CGFloat = TacticalGlassTheme.cornerRadius) {
        self.init(source: .remote(photos, accessToken: accessToken), columnCount: columnCount, spacing: spacing, cornerRadius: cornerRadius)
    }

    init(images: [UIImage], columnCount: Int = 3, spacing: CGFloat = 10, cornerRadius: CGFloat = TacticalGlassTheme.cornerRadius) {
        self.init(source: .local(images), columnCount: columnCount, spacing: spacing, cornerRadius: cornerRadius)
    }

    var body: some View {
        Group {
            if itemCount == 0 {
                EmptyView()
            } else {
                gridContent
                    .fullScreenCover(item: $previewSession) { session in
                        TacticalPhotoAlbumFullScreenView(source: source, startIndex: session.startIndex)
                    }
            }
        }
    }

    private var gridContent: some View {
        let side = (layoutWidth - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        let rowCount = max(1, Int(ceil(Double(itemCount) / Double(cols))))
        let totalHeight = CGFloat(rowCount) * side + CGFloat(max(0, rowCount - 1)) * spacing

        return VStack(spacing: spacing) {
            ForEach(0 ..< rowCount, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0 ..< cols, id: \.self) { col in
                        let index = row * cols + col
                        Group {
                            if index < itemCount {
                                thumbnailButton(index: index, side: side)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .frame(height: side)
            }
        }
        .frame(height: totalHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: AlbumGridWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(AlbumGridWidthPreferenceKey.self) { w in
            guard w > 0, abs(w - measuredContainerWidth) > 0.5 else { return }
            measuredContainerWidth = w
        }
    }

    @ViewBuilder
    private func thumbnailButton(index: Int, side _: CGFloat) -> some View {
        Button {
            previewSession = PhotoPreviewSession(startIndex: index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(TacticalGlassTheme.surfaceContainerLowest)
                switch source {
                case .remote(let photos, let token):
                    AuthenticatedRemoteImage(apiPath: photos[index].url, accessToken: token)
                case .local(let images):
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("照片 \(index + 1)，共 \(itemCount) 張")
        .accessibilityAddTraits(.isButton)
    }
}

private struct TacticalPhotoAlbumFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    let source: TacticalPhotoAlbumSource
    @State private var selection: Int

    init(source: TacticalPhotoAlbumSource, startIndex: Int) {
        self.source = source
        let maxIdx = max(0, source.count - 1)
        _selection = State(initialValue: min(max(0, startIndex), maxIdx))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: $selection) {
                    ForEach(0 ..< source.count, id: \.self) { index in
                        previewPage(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: source.count > 1 ? .automatic : .never))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .accessibilityLabel("關閉")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func previewPage(for index: Int) -> some View {
        Group {
            switch source {
            case .remote(let photos, let token):
                AuthenticatedRemoteImage(apiPath: photos[index].url, accessToken: token, scaledToFit: true)
            case .local(let images):
                Image(uiImage: images[index])
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }
}

// MARK: - PhotosPicker → UIImage previews (create forms)

enum PhotoPickerPreviewLoader {
    /// 供 `onChange` 偵測選取是否變更（`itemIdentifier` 可能為 nil，仍帶入 index）。
    static func fingerprint(for items: [PhotosPickerItem]) -> String {
        "\(items.count):" + items.enumerated().map { "\($0.offset)_\($0.element.itemIdentifier ?? "?")" }.joined(separator: "|")
    }

    @MainActor
    static func uiImages(from items: [PhotosPickerItem]) async -> [UIImage] {
        guard !items.isEmpty else { return [] }
        var out: [UIImage] = []
        out.reserveCapacity(items.count)
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data) else { continue }
            out.append(ui)
        }
        return out
    }
}

