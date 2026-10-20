import SwiftUI

/// The transparent sticker for Instagram stories (SPEC §9): stats, plus the trail as a plain
/// line (no map tiles) when the map is shown. White with a soft shadow to read over any photo.
struct StickerView: View {
    let content: ShareContent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Barhop")
                    .textCase(.uppercase)
                    .font(Theme.Typography.shareWordmark)
                    .tracking(Theme.Typography.wordmarkTracking)
                Text(content.title)
                    .font(Theme.Typography.shareTitle)
            }
            if content.drawsMap {
                TrailSketch(
                    segments: content.segments,
                    venues: content.venues,
                    color: Theme.Palette.stickerText,
                    gapColor: Theme.Palette.stickerText,
                    stroke: Theme.Stroke.shareTrail,
                    gapStroke: Theme.Stroke.shareTrailGap,
                    pinSize: Theme.Size.stickerPin
                )
                .frame(width: Theme.Size.stickerTrail.width, height: Theme.Size.stickerTrail.height)
            }
            ShareStatsGrid(content: content, valueFont: Theme.Typography.stickerStatValue, labelColor: Theme.Palette.stickerText)
        }
        .foregroundStyle(Theme.Palette.stickerText)
        .shadow(color: Theme.Palette.stickerShadow, radius: Theme.Size.stickerShadowRadius)
        .padding(Theme.Spacing.medium)
        .frame(width: Theme.Size.stickerWidth, alignment: .leading)
    }
}
