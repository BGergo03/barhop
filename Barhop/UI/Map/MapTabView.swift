import SwiftUI

/// Placeholder until the Map tab is built (SPEC §11, M13).
struct MapTabView: View {
    var body: some View {
        EmptyStateRow(systemImage: "map", message: "A map of your places is coming soon.")
            .padding(.horizontal, Theme.Spacing.screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .navigationTitle("Map")
    }
}
