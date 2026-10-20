import Observation

enum AppTab: Hashable {
    case home
    case search
    case map
    case profile
}

enum Route: Hashable {
    case report(Night)
    case settings
}

/// Which tab is showing, each tab's navigation path, and the full-screen Live night cover.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [Route] = []
    var profilePath: [Route] = []
    /// The night shown in the Live night cover while it's up.
    var liveNight: Night?

    func openLiveNight(_ night: Night) {
        liveNight = night
    }

    func showAllNights() {
        selectedTab = .profile
        profilePath = []
    }

    /// Opens the live night whenever one starts (or is already running at launch),
    /// and shows the report as soon as it ends, whatever ended it.
    func activeNightChanged(from previous: Night?, to current: Night?) {
        if let current {
            liveNight = current
        } else if let previous {
            liveNight = nil
            selectedTab = .home
            homePath = [.report(previous)]
        }
    }
}
