import SwiftUI

/// Placeholder until the Search tab is built (SPEC §11, M14).
struct SearchView: View {
    var body: some View {
        EmptyStateRow(systemImage: "magnifyingglass", message: "Searching places and drinks is coming soon.")
            .padding(.horizontal, Theme.Spacing.screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .navigationTitle("Search")
    }
}
