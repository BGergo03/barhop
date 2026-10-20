import SwiftUI
import UniformTypeIdentifiers

/// An ended night: stats, map, venues and the editable timeline (SPEC §7).
/// Stats are recomputed from the night on every render, so timeline edits show up immediately.
struct ReportView: View {
    let night: Night
    @Environment(NightEngine.self) private var engine
    @State private var selectedVenue: Venue?
    @State private var openedPlace: Place?
    @State private var editingEntry: Entry?
    @State private var copiedStickers = 0

    private var hasLocation: Bool { !night.trailPoints.isEmpty || !night.venues.isEmpty }

    var body: some View {
        let stats = ReportStats(night: night)
        List {
            Section {
                hero(stats)
                    .bareRow()
            }
            if hasLocation {
                Section {
                    TrailMap(night: night, isLive: false, selectedVenue: $selectedVenue)
                        .frame(height: Theme.Size.reportMapHeight)
                        .listRowInsets(EdgeInsets())
                        .cardRow()
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
                .font(Theme.Typography.body)
                .cardRow()
            }
            Section {
                Menu {
                    shareMenuItems
                } label: {
                    Label("Share your night", systemImage: "square.and.arrow.up")
                        .font(Theme.Typography.primaryButton)
                        .foregroundStyle(Theme.Palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
                        .background(Theme.Gradients.accent, in: .capsule)
                }
                .bareRow()
                .padding(.bottom, Theme.Spacing.large)
            }
        }
        .cardList()
        .navigationTitle(night.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                shareMenuItems
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .sensoryFeedback(.success, trigger: copiedStickers)
        // Sheets hang off the List, not its rows, so they survive the List re-rendering.
        .sheet(item: $selectedVenue) { venue in
            VenueSheet(venue: venue) { openedPlace = $0 }
        }
        .navigationDestination(item: $openedPlace) { place in
            PlaceDetailView(place: place)
        }
        .entryTimeEditor($editingEntry)
    }

    private func hero(_ stats: ReportStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text(stats.duration.durationText)
                .font(Theme.Typography.screenTitle)
                .foregroundStyle(Theme.Palette.primaryText)
            HStack(spacing: Theme.Spacing.small) {
                Text(night.startedAt, format: .dateTime.hour().minute())
                if let endedAt = night.endedAt {
                    Text(verbatim: "–")
                    Text(endedAt, format: .dateTime.hour().minute())
                }
                if night.endReason == .autoClosed {
                    Text("Auto-closed")
                        .font(Theme.Typography.statLabel)
                        .textCase(.uppercase)
                        .tracking(Theme.Typography.labelTracking)
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, Theme.Spacing.small)
                        .padding(.vertical, Theme.Spacing.xSmall / 2)
                        .background(Theme.Palette.accent.opacity(0.15), in: .capsule)
                }
            }
            .font(Theme.Typography.body.monospacedDigit())
            .foregroundStyle(Theme.Palette.secondaryText)
        }
        .padding(.vertical, Theme.Spacing.small)
    }

    private func statsSection(_ stats: ReportStats) -> some View {
        Section {
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.medium, verticalSpacing: Theme.Spacing.large) {
                GridRow {
                    StatTile(label: "Beers", value: Text(stats.beers, format: .number), accented: true)
                    StatTile(label: "Liters", value: Text(stats.liters, format: .number.precision(.fractionLength(1))))
                }
                GridRow {
                    StatTile(label: "Beers per hour", value: stats.pace.map { Text($0, format: .number.precision(.fractionLength(1))) } ?? Text("—"))
                    StatTile(label: "Longest gap", value: Text(stats.longestGap?.durationText ?? "—"))
                }
                if hasLocation {
                    GridRow {
                        StatTile(
                            label: "Distance",
                            value: Text(Measurement(value: stats.distance, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                        )
                        StatTile(label: "Places", value: Text(stats.venues.count, format: .number))
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.small)
            .cardRow()
        }
    }

    private func venuesSection(_ venues: [ReportStats.VenueTime]) -> some View {
        Section {
            ForEach(Array(venues.enumerated()), id: \.element.id) { index, venueTime in
                let venue = night.venues.first { $0.id == venueTime.id }
                // A linked stop opens its place; an unlinked one goes straight to the fix-up sheet.
                Button {
                    if let place = venue?.place {
                        openedPlace = place
                    } else {
                        selectedVenue = venue
                    }
                } label: {
                    VenueTimeRow(index: index + 1, venueTime: venueTime, isLinked: venue?.place != nil)
                }
                .tint(Theme.Palette.primaryText)
                .cardRow()
                .swipeActions {
                    Button("Rename") {
                        selectedVenue = venue
                    }
                    .tint(Theme.Palette.accentDeep)
                }
            }
        } header: {
            SectionLabel("Places")
        }
    }

    @ViewBuilder
    private var shareMenuItems: some View {
        let content = ShareContent(night: night)
        ShareLink(item: ShareImage(kind: .card, content: content), preview: SharePreview(night.title)) {
            Label("Card (PNG)", systemImage: "rectangle.portrait")
        }
        ShareLink(item: ShareImage(kind: .sticker, content: content), preview: SharePreview(night.title)) {
            Label("Sticker (PNG)", systemImage: "seal")
        }
        Button("Copy sticker", systemImage: "doc.on.doc") {
            copySticker(content)
        }
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
    let index: Int
    let venueTime: ReportStats.VenueTime
    let isLinked: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Text(index, format: .number)
                .font(Theme.Typography.statLabel)
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: Theme.Size.placeIndex, height: Theme.Size.placeIndex)
                .background(Theme.Gradients.accent, in: .circle)
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall / 2) {
                Text(venueTime.name)
                    .font(Theme.Typography.body)
                    .lineLimit(1)
                Text(venueTime.arrivedAt, format: .dateTime.hour().minute())
                    .font(Theme.Typography.caption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            Text(venueTime.timeSpent.durationText)
                .font(Theme.Typography.body.monospacedDigit())
                .foregroundStyle(Theme.Palette.secondaryText)
            if isLinked {
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.tertiaryText)
            }
        }
    }
}
