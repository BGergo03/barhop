import SwiftUI

/// The 9:16 share card (1080×1920 px at 3×), opaque (SPEC §9).
struct CardView: View {
    let content: ShareContent
    /// The snapshot from `MapSnapshot`; `nil` leaves the map out.
    let map: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
                Text("Barhop")
                    .font(Theme.Typography.shareWordmark)
                Text(content.title)
                    .font(Theme.Typography.shareTitle)
                    .foregroundStyle(Theme.Palette.shareSecondaryText)
            }

            ShareStatsGrid(content: content, valueFont: Theme.Typography.shareStatValue)

            if let map {
                Image(uiImage: map)
                    .resizable()
                    .scaledToFill()
                    .frame(height: Theme.Size.shareMapHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.shareMap))
            }

            if !content.venueNames.isEmpty {
                venueList
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.Palette.shareText)
        .padding(Theme.Size.shareCardPadding)
        .frame(width: Theme.Size.shareCard.width, height: Theme.Size.shareCard.height, alignment: .topLeading)
        .background(Theme.Palette.shareBackground)
    }

    /// Ordered names on a few wrapped lines, so a long crawl still fits under the map.
    private var venueList: some View {
        let listed = content.listedVenues
        let route = listed.names.joined(separator: " → ")
        return VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
            Text("\(content.venueNames.count) places")
                .font(Theme.Typography.shareStatLabel)
                .foregroundStyle(Theme.Palette.shareSecondaryText)
            Group {
                if listed.more > 0 {
                    Text("\(route) +\(listed.more) more")
                } else {
                    Text(route)
                }
            }
            .font(Theme.Typography.shareBody)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Duration, beers, liters and (with a trail) distance, two per row.
struct ShareStatsGrid: View {
    let content: ShareContent
    let valueFont: Font

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.large, verticalSpacing: Theme.Spacing.medium) {
            GridRow {
                stat("Duration", content.duration.durationText)
                stat("Beers", content.beers.formatted())
            }
            GridRow {
                stat("Liters", content.liters.formatted(.number.precision(.fractionLength(1))))
                if let distance = content.distance {
                    stat("Distance", Measurement(value: distance, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))
                }
            }
        }
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(valueFont)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.Typography.shareStatLabel)
                .foregroundStyle(Theme.Palette.shareSecondaryText)
        }
    }
}
