import SwiftData
import SwiftUI

/// Every past night and the way to Settings (SPEC §7).
struct ProfileView: View {
    @Environment(NightEngine.self) private var engine
    @Query(filter: #Predicate<Night> { $0.endedAt != nil }, sort: \Night.startedAt, order: .reverse)
    private var pastNights: [Night]
    @State private var nightPendingDeletion: Night?

    var body: some View {
        List {
            header
                .floatingBareRow()
            SectionLabel("Nights")
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
                    // No destructive role: it makes the List remove the row before the
                    // confirmation dialog, then put it back while the dialog is up.
                    Button("Delete") {
                        nightPendingDeletion = night
                    }
                    .tint(Theme.Palette.danger)
                }
            }
        }
        .floatingCardList()
        .toolbar(.hidden, for: .navigationBar)
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
            Text("Profile")
                .font(Theme.Typography.screenTitle)
                .foregroundStyle(Theme.Palette.primaryText)
            Spacer()
            NavigationLink(value: Route.settings) {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(.icon)
        }
        .padding(.top, Theme.Spacing.small)
    }
}
