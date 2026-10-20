import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(NightEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Night> { $0.endedAt == nil }) private var activeNights: [Night]
    @Query(Self.recentNightsDescriptor) private var recentNights: [Night]

    private static let recentNightsLimit = 3

    private static var recentNightsDescriptor: FetchDescriptor<Night> {
        var descriptor = FetchDescriptor<Night>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = recentNightsLimit
        return descriptor
    }

    var body: some View {
        List {
            header
                .floatingBareRow()
            hero
                .floatingBareRow()
            recentNightsLabel
                .floatingBareRow()
            if recentNights.isEmpty {
                EmptyStateRow(systemImage: "moon.stars", message: "Your nights will show up here.")
                    .floatingCardRow()
            }
            ForEach(recentNights) { night in
                NavigationLink(value: Route.report(night)) {
                    NightRow(night: night)
                }
                .floatingCardRow()
            }
        }
        .floatingCardList()
        .background(alignment: .top) {
            Theme.Gradients.backdropGlow
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        Wordmark()
            .frame(maxWidth: .infinity, minHeight: Theme.Size.iconButton, alignment: .leading)
            .padding(.top, Theme.Spacing.small)
    }

    private var recentNightsLabel: some View {
        HStack {
            SectionLabel("Recent nights")
            Spacer()
            if !recentNights.isEmpty {
                Button("See all") {
                    router.showAllNights()
                }
                .font(Theme.Typography.secondaryButton)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.accent)
            }
        }
        .padding(.horizontal, Theme.Spacing.xSmall)
    }

    @ViewBuilder
    private var hero: some View {
        if let active = activeNights.first {
            Button {
                router.openLiveNight(active)
            } label: {
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
