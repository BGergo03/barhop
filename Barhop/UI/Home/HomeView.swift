import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(NightEngine.self) private var engine
    @Query(filter: #Predicate<Night> { $0.endedAt == nil }) private var activeNights: [Night]
    @Query(filter: #Predicate<Night> { $0.endedAt != nil }, sort: \Night.startedAt, order: .reverse)
    private var pastNights: [Night]
    @State private var nightPendingDeletion: Night?
    @State private var showsSettings = false

    var body: some View {
        List {
            header
                .floatingBareRow()
            hero
                .floatingBareRow()
            SectionLabel("Past nights")
                .padding(.leading, Theme.Spacing.xSmall)
                .floatingBareRow()
            if pastNights.isEmpty {
                EmptyStateRow(systemImage: "moon.stars", message: "Your nights will show up here.")
                    .floatingCardRow()
            }
            ForEach(pastNights) { night in
                NavigationLink(value: Route.report(night)) {
                    NightRow(night: night)
                }
                .floatingCardRow()
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        nightPendingDeletion = night
                    }
                }
            }
        }
        .floatingCardList()
        .background(alignment: .top) {
            Theme.Gradients.backdropGlow
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Delete this night?",
            isPresented: Binding(
                get: { nightPendingDeletion != nil },
                set: { if !$0 { nightPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: nightPendingDeletion
        ) { night in
            Button("Delete night", role: .destructive) {
                engine.deleteNight(night)
            }
        } message: { _ in
            Text("Its beers, route and places will be removed.")
        }
    }

    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            Button {
                showsSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(.icon)
        }
        .padding(.top, Theme.Spacing.small)
    }

    @ViewBuilder
    private var hero: some View {
        if let active = activeNights.first {
            NavigationLink(value: Route.live(active)) {
                ActiveNightCard(night: active)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                    Text("Ready when you are")
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.Palette.primaryText)
                    Text("Start a night to map your route and count your beers.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                Button {
                    engine.startNight()
                } label: {
                    Label("Start night", systemImage: "moon.stars.fill")
                }
                .buttonStyle(.primary)
            }
            // Room inside the row for the glow, which the List would otherwise clip.
            .padding(.top, Theme.Spacing.medium)
            .padding(.bottom, Theme.Shadow.glowRadius + Theme.Shadow.glowOffset)
        }
    }
}

/// The night in progress, with a live timer, in place of the Start button.
private struct ActiveNightCard: View {
    let night: Night

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                Label("Night in progress", systemImage: "dot.radiowaves.left.and.right")
                    .font(Theme.Typography.statLabel)
                    .textCase(.uppercase)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.Palette.onAccent.opacity(0.75))
                Text(night.startedAt, style: .timer)
                    .font(Theme.Typography.timer)
                if let venue = night.currentVenue {
                    Text(venue.name)
                        .font(Theme.Typography.caption)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(night.beerCount, format: .number)
                    .font(Theme.Typography.heroCount)
                Text("Resume")
                    .font(Theme.Typography.secondaryButton)
            }
        }
        .foregroundStyle(Theme.Palette.onAccent)
        .padding(Theme.Spacing.large)
        .background(Theme.Gradients.accent, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.Palette.glow, radius: Theme.Shadow.glowRadius, y: Theme.Shadow.glowOffset)
        .padding(.top, Theme.Spacing.small)
        .padding(.bottom, Theme.Shadow.glowRadius + Theme.Shadow.glowOffset)
    }
}

private struct NightRow: View {
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
