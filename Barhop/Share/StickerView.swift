import SwiftUI

/// The transparent sticker for Instagram stories (SPEC §9): stats, plus the trail as a plain
/// line (no map tiles) when the map is shown. White with a soft shadow to read over any photo.
struct StickerView: View {
    let content: ShareContent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Barhop")
                    .font(Theme.Typography.shareWordmark)
                Text(content.title)
                    .font(Theme.Typography.shareTitle)
            }
            if content.drawsMap {
                StickerTrail(content: content)
                    .frame(width: Theme.Size.stickerTrail.width, height: Theme.Size.stickerTrail.height)
            }
            ShareStatsGrid(content: content, valueFont: Theme.Typography.stickerStatValue)
        }
        .foregroundStyle(Theme.Palette.shareText)
        .shadow(color: Theme.Palette.stickerShadow, radius: Theme.Size.stickerShadowRadius)
        .padding(Theme.Spacing.medium)
        .frame(width: Theme.Size.stickerWidth, alignment: .leading)
    }
}

private struct StickerTrail: View {
    let content: ShareContent

    var body: some View {
        Canvas { context, size in
            let projection = TrailProjection(
                fitting: content.segments.flatMap { $0 } + content.venues,
                in: size,
                inset: Theme.Size.stickerPin
            )
            let segments = content.segments.map { $0.map(projection.point(for:)) }
            context.stroke(path(TrailGeometry.gaps(between: segments)), with: .color(Theme.Palette.shareText), style: Theme.Stroke.shareTrailGap)
            context.stroke(path(segments), with: .color(Theme.Palette.shareText), style: Theme.Stroke.shareTrail)
            let diameter = Theme.Size.stickerPin
            for venue in content.venues {
                let center = projection.point(for: venue)
                let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(Theme.Palette.shareText))
            }
        }
    }

    private func path(_ lines: [[CGPoint]]) -> Path {
        Path { path in
            for line in lines where line.count > 1 {
                path.addLines(line)
            }
        }
    }
}
