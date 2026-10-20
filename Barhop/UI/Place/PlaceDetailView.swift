import SwiftUI

/// A lasting place and your visits to it (SPEC §7). The menu, map and Save arrive in M12.
struct PlaceDetailView: View {
    let place: Place

    var body: some View {
        List {
            Section {
                header
                    .bareRow()
            }
            Section {
                if place.visits.isEmpty {
                    EmptyStateRow(systemImage: "mappin.and.ellipse", message: "Your visits will show up here.")
                        .cardRow()
                }
                ForEach(place.visits) { stop in
                    if let night = stop.night {
                        NavigationLink(value: Route.report(night)) {
                            VisitRow(night: night, stop: stop)
                        }
                        .cardRow()
                    }
                }
            } header: {
                SectionLabel("Your visits")
            }
        }
        .cardList()
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(place.name)
                .font(Theme.Typography.screenTitle)
                .foregroundStyle(Theme.Palette.primaryText)
            if let address = place.address {
                Text(address)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
        }
        .padding(.vertical, Theme.Spacing.small)
    }
}

private struct VisitRow: View {
    let night: Night
    let stop: Venue

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall / 2) {
                Text(night.title)
                    .font(Theme.Typography.body)
                Text(stop.arrivedAt, format: .dateTime.hour().minute())
                    .font(Theme.Typography.caption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            Text(((stop.leftAt ?? night.endedAt ?? stop.arrivedAt).timeIntervalSince(stop.arrivedAt)).durationText)
                .font(Theme.Typography.body.monospacedDigit())
                .foregroundStyle(Theme.Palette.secondaryText)
        }
    }
}
