import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// Renders the share card and sticker to PNG (SPEC §9).
@MainActor
enum ShareRenderer {
    enum Kind: String, Sendable {
        case card
        case sticker
    }

    struct RenderError: Error {}

    static func png(_ kind: Kind, for content: ShareContent) async throws -> Data {
        let renderer: ImageRenderer<AnyView>
        switch kind {
        case .card:
            let map = content.drawsMap ? await MapSnapshot.image(for: content, size: mapSize) : nil
            renderer = ImageRenderer(content: AnyView(CardView(content: content, map: map)))
            renderer.isOpaque = true
        case .sticker:
            renderer = ImageRenderer(content: AnyView(StickerView(content: content)))
            renderer.isOpaque = false
        }
        renderer.scale = Theme.Size.shareRenderScale
        guard let data = renderer.uiImage?.pngData() else { throw RenderError() }
        return data
    }

    /// Writes the PNG as `Barhop-YYYY-MM-DD.png`. Card and sticker get their own folders,
    /// since they share the file name.
    static func file(_ kind: Kind, for content: ShareContent) async throws -> URL {
        let data = try await png(kind, for: content)
        let folder = URL.temporaryDirectory.appending(path: "Share/\(kind.rawValue)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: ShareContent.fileName(for: content.startedAt))
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The card's map spans its width inside the padding.
    private static var mapSize: CGSize {
        CGSize(width: Theme.Size.shareCard.width - 2 * Theme.Size.shareCardPadding, height: Theme.Size.shareMapHeight)
    }
}

/// A card or sticker for `ShareLink`, rendered only when the user actually shares it.
struct ShareImage: Transferable {
    var kind: ShareRenderer.Kind
    var content: ShareContent

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { image in
            SentTransferredFile(try await ShareRenderer.file(image.kind, for: image.content))
        }
    }
}
