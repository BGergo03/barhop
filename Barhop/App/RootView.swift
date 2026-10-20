import SwiftData
import SwiftUI

struct RootView: View {
    @Query(filter: #Predicate<Night> { $0.endedAt == nil }) private var activeNights: [Night]
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView()
                        .routeDestinations()
                }
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                NavigationStack {
                    SearchView()
                }
            }
            Tab("Map", systemImage: "map.fill", value: AppTab.map) {
                NavigationStack {
                    MapTabView()
                }
            }
            Tab("Profile", systemImage: "person.fill", value: AppTab.profile) {
                NavigationStack(path: $router.profilePath) {
                    ProfileView()
                        .routeDestinations()
                }
            }
        }
        .tabViewBottomAccessory(isEnabled: activeNights.first != nil) {
            if let night = activeNights.first {
                NightPill(night: night)
            }
        }
        .fullScreenCover(item: $router.liveNight) { night in
            NavigationStack {
                LiveNightView(night: night)
            }
        }
        .environment(router)
        .onChange(of: activeNights.first, initial: true) { previous, current in
            router.activeNightChanged(from: previous, to: current)
        }
    }
}

private extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .report(let night): ReportView(night: night)
            case .settings: SettingsView()
            }
        }
    }
}
