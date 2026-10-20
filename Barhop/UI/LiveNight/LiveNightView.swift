import SwiftUI

/// The night in progress, as a full-screen cover over the tabs: the map fills the screen, with
/// the stats floating on top and the big "+1 Beer" at the bottom. The timeline opens as a sheet.
/// Closing it leaves the night running, reachable from the pill above the tab bar.
struct LiveNightView: View {
    let night: Night
    @Environment(NightEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsEnd = false
    @State private var selectedVenue: Venue?
    @State private var openedPlace: Place?
    @State private var editingEntry: Entry?
    @State private var showsTimeline = false

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Theme.Spacing.medium) {
                statsPanel
                if engine.isLocationDenied {
                    LocationOffPrompt()
                        .card()
                }
                Spacer()
                beerPanel
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.small)
        }
        .navigationTitle(night.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "chevron.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("End night", role: .destructive) {
                    confirmsEnd = true
                }
                .buttonStyle(.destructiveSecondary)
            }
        }
        .sheet(item: $selectedVenue) { venue in
            VenueSheet(venue: venue) { openedPlace = $0 }
        }
        .navigationDestination(item: $openedPlace) { place in
            PlaceDetailView(place: place)
        }
        .sheet(isPresented: $showsTimeline) {
            TimelineSheet(night: night)
        }
        .entryTimeEditor($editingEntry)
        .confirmationDialog("End this night?", isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button("End night", role: .destructive) {
                engine.endNight(night)
            }
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        if engine.isLocationDenied {
            ZStack {
                Theme.Palette.background
                Theme.Gradients.backdropGlow
            }
            .ignoresSafeArea()
        } else {
            TrailMap(night: night, isLive: true, selectedVenue: $selectedVenue)
                // Keeps the camera and map controls clear of the floating panels.
                .safeAreaPadding(.top, Theme.Size.liveMapTopInset)
                .safeAreaPadding(.bottom, Theme.Size.liveMapBottomInset)
                .overlay(alignment: .top) {
                    Theme.Gradients.mapTopScrim
                        .frame(height: Theme.Size.liveMapTopInset)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    Theme.Gradients.mapBottomScrim
                        .frame(height: Theme.Size.liveMapBottomInset)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
        }
    }

    private var statsPanel: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                Text(night.startedAt, style: .timer)
                    .font(Theme.Typography.timer)
                    .foregroundStyle(Theme.Palette.primaryText)
                Button {
                    openCurrentVenue()
                } label: {
                    Label(night.currentVenue?.name ?? String(localized: "On the move"), systemImage: "mappin")
                        .labelStyle(CompactLabelStyle())
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text(night.beerCount, format: .number)
                    .font(Theme.Typography.heroCount)
                    .foregroundStyle(Theme.Gradients.accent)
                    .contentTransition(.numericText())
                    .animation(.default, value: night.beerCount)
                Text("Beers")
                    .textCase(.uppercase)
                    .font(Theme.Typography.statLabel)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
        }
        .floatingPanel()
    }

    /// The place you're at, or the fix-up sheet when the stop isn't linked to one yet.
    private func openCurrentVenue() {
        guard let venue = night.currentVenue else { return }
        if let place = venue.place {
            openedPlace = place
        } else {
            selectedVenue = venue
        }
    }

    private var beerPanel: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Button {
                engine.logBeer()
            } label: {
                Label("+1 Beer", systemImage: "mug.fill")
            }
            .buttonStyle(.primary(height: Theme.Size.beerButtonHeight))
            .sensoryFeedback(.success, trigger: night.beerCount)

            HStack {
                if let last = night.sortedEntries.first {
                    Button {
                        editingEntry = last
                    } label: {
                        HStack(spacing: Theme.Spacing.xSmall) {
                            Text("Last beer")
                                .foregroundStyle(Theme.Palette.secondaryText)
                            Text(last.timestamp, format: .dateTime.hour().minute())
                                .monospacedDigit()
                                .foregroundStyle(Theme.Palette.primaryText)
                        }
                        .font(Theme.Typography.caption)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No beers yet")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                Spacer()
                Button {
                    showsTimeline = true
                } label: {
                    Label("Timeline", systemImage: "list.bullet")
                }
                .buttonStyle(.secondary)
            }
        }
        .floatingPanel()
    }
}

/// Every entry of the live night, editable like in the report.
private struct TimelineSheet: View {
    let night: Night
    @Environment(\.dismiss) private var dismiss
    @State private var editingEntry: Entry?

    var body: some View {
        NavigationStack {
            List {
                EntryTimelineSection(night: night, editingEntry: $editingEntry)
            }
            .cardList()
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .entryTimeEditor($editingEntry)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.Palette.background)
    }
}
