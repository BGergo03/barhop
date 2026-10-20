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
            Section {
                if let active = activeNights.first {
                    NavigationLink(value: Route.live(active)) {
                        Text("Resume night")
                    }
                    .buttonStyle(.primary)
                } else {
                    Button("Start night") {
                        engine.startNight()
                    }
                    .buttonStyle(.primary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section("Past nights") {
                if pastNights.isEmpty {
                    Text("Your nights will show up here.")
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                ForEach(pastNights) { night in
                    NavigationLink(value: Route.report(night)) {
                        NightRow(night: night)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            nightPendingDeletion = night
                        }
                    }
                }
            }
        }
        .navigationTitle("Barhop")
        .toolbar {
            Button {
                showsSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
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
}

private struct NightRow: View {
    let night: Night

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
            Text(night.title)
                .font(Theme.Typography.headline)
            HStack(spacing: Theme.Spacing.medium) {
                Text(night.duration().durationText)
                Text("🍺 \(night.beerCount)")
                Text("📍 \(night.venues.count)")
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.secondaryText)
        }
    }
}
