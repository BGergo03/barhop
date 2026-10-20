import SwiftData
import SwiftUI

enum Route: Hashable {
    case live(Night)
    case report(Night)
}

struct RootView: View {
    @Query(filter: #Predicate<Night> { $0.endedAt == nil }) private var activeNights: [Night]
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .live(let night): LiveNightView(night: night)
                    case .report(let night): ReportView(night: night)
                    }
                }
        }
        // Open straight into the live night whenever one is (or becomes) active,
        // and show the report as soon as it ends, whatever ended it.
        .onChange(of: activeNights.first, initial: true) { previous, current in
            if let current {
                if path.last != .live(current) { path = [.live(current)] }
            } else if let previous {
                path = [.report(previous)]
            }
        }
    }
}
