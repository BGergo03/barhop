import SwiftUI

/// An ended night: stats, map, venues and the editable timeline (SPEC §7).
/// Stats are recomputed from the night on every render, so timeline edits show up immediately.
struct ReportView: View {
    let night: Night
    @Environment(NightEngine.self) private var engine
    @State private var selectedVenue: Venue?

    private var hasLocation: Bool { !night.trailPoints.isEmpty || !night.venues.isEmpty }

    var body: some View {
        let stats = ReportStats(night: night)
        List {
            if hasLocation {
                Section {
                    TrailMap(night: night, isLive: false)
                        .frame(height: Theme.Size.reportMapHeight)
                        .listRowInsets(EdgeInsets())
                }
            }
            statsSection(stats)
            if !stats.venues.isEmpty {
                venuesSection(stats.venues)
            }
            EntryTimelineSection(night: night)
            Section {
                Toggle("Show map on share", isOn: Binding(
                    get: { night.showMapOnShare },
                    set: { engine.setShowMapOnShare($0, for: night) }
                ))
            }
        }
        .navigationTitle(night.title)
        .toolbar {
            shareMenu
        }
        .sheet(item: $selectedVenue) { venue in
            VenueSheet(venue: venue)
        }
    }

    private func statsSection(_ stats: ReportStats) -> some View {
        Section {
            LabeledContent("Duration", value: stats.duration.durationText)
            LabeledContent("Beers", value: stats.beers, format: .number)
            LabeledContent("Liters", value: stats.liters, format: .number.precision(.fractionLength(1)))
            LabeledContent("Pace") {
                if let pace = stats.pace {
                    Text("\(pace, format: .number.precision(.fractionLength(1))) per hour")
                } else {
                    Text("—")
                }
            }
            LabeledContent("Longest gap") {
                if let gap = stats.longestGap {
                    Text(gap.durationText)
                } else {
                    Text("—")
                }
            }
            if hasLocation {
                LabeledContent(
                    "Distance",
                    value: Measurement(value: stats.distance, unit: UnitLength.meters),
                    format: .measurement(width: .abbreviated, usage: .road)
                )
            }
        }
    }

    private func venuesSection(_ venues: [ReportStats.VenueTime]) -> some View {
        Section("Places") {
            ForEach(venues) { venueTime in
                Button {
                    selectedVenue = night.venues.first { $0.id == venueTime.id }
                } label: {
                    VenueTimeRow(venueTime: venueTime)
                }
                .tint(Theme.Palette.primaryText)
            }
        }
    }

    /// Export lands in M8; the menu is here so the layout is final.
    private var shareMenu: some View {
        Menu {
            Button("Card (PNG)") {}
            Button("Sticker (PNG)") {}
            Button("Copy sticker") {}
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(true)
    }
}

private struct VenueTimeRow: View {
    let venueTime: ReportStats.VenueTime

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
                Text(venueTime.name)
                Text(venueTime.arrivedAt, format: .dateTime.hour().minute())
                    .font(Theme.Typography.caption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            Text(venueTime.timeSpent.durationText)
                .font(Theme.Typography.body.monospacedDigit())
                .foregroundStyle(Theme.Palette.secondaryText)
        }
    }
}
