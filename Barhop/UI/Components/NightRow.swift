import SwiftUI

/// A past night: title, duration, beers, stops and a sketch of the route.
struct NightRow: View {
    let night: Night

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(night.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.primaryText)
                HStack(spacing: Theme.Spacing.medium) {
                    Label(night.duration().durationText, systemImage: "clock")
                    Label("\(night.beerCount)", systemImage: "mug.fill")
                    Label("\(night.venues.count)", systemImage: "mappin")
                }
                .labelStyle(CompactLabelStyle())
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer(minLength: 0)
            if !night.trailPoints.isEmpty {
                TrailSketch(segments: TrailGeometry.segmentPoints(night.trailPoints), venues: night.venues.map(\.mapPoint))
                    .frame(width: Theme.Size.trailThumbnail.width, height: Theme.Size.trailThumbnail.height)
                    .background(Theme.Palette.surfaceRaised, in: .rect(cornerRadius: Theme.Radius.thumbnail))
            }
        }
        .padding(.vertical, Theme.Spacing.xSmall)
    }
}

/// Icon and text close together, icon in the accent color.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.xSmall) {
            configuration.icon
                .foregroundStyle(Theme.Palette.accent)
            configuration.title
        }
    }
}
