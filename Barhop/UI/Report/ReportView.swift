import SwiftUI
import UniformTypeIdentifiers

/// An ended night: stats, map, venues and the editable timeline (SPEC §7).
/// Stats are recomputed from the night on every render, so timeline edits show up immediately.
struct ReportView: View {
    let night: Night
    @Environment(NightEngine.self) private var engine
    @State private var selectedVenue: Venue?
    @State private var editingEntry: Entry?
    @State private var copiedStickers = 0

    private var hasLocation: Bool { !night.trailPoints.isEmpty || !night.venues.isEmpty }

    var body: some View {
        let stats = ReportStats(night: night)
        List {
            if hasLocation {
                Section {
                    TrailMap(night: night, isLive: false, selectedVenue: $selectedVenue)
                        .frame(height: Theme.Size.reportMapHeight)
                        .listRowInsets(EdgeInsets())
                }
            }
            statsSection(stats)
            if !stats.venues.isEmpty {
                venuesSection(stats.venues)
            }
            EntryTimelineSection(night: night, editingEntry: $editingEntry)
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
        // Sheets hang off the List, not its rows, so they survive the List re-rendering.
        .sheet(item: $selectedVenue) { venue in
            VenueSheet(venue: venue)
        }
        .entryTimeEditor($editingEntry)
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

    /// Card and sticker render only when chosen, from the night as it is at that moment.
    private var shareMenu: some View {
        let content = ShareContent(night: night)
        return Menu {
            ShareLink(item: ShareImage(kind: .card, content: content), preview: SharePreview(night.title)) {
                Label("Card (PNG)", systemImage: "rectangle.portrait")
            }
            ShareLink(item: ShareImage(kind: .sticker, content: content), preview: SharePreview(night.title)) {
                Label("Sticker (PNG)", systemImage: "seal")
            }
            Button("Copy sticker", systemImage: "doc.on.doc") {
                copySticker(content)
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .sensoryFeedback(.success, trigger: copiedStickers)
    }

    /// For pasting straight into an Instagram story.
    private func copySticker(_ content: ShareContent) {
        Task {
            guard let png = try? await ShareRenderer.png(.sticker, for: content) else { return }
            UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
            copiedStickers += 1
        }
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
