import SwiftData
import SwiftUI

@main
struct BarhopApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Runs on background relaunches by Core Location too, where no scene becomes active.
        NightEngine.shared.resumeTrackingIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(NightEngine.shared)
                .preferredColorScheme(Theme.colorScheme)
        }
        .modelContainer(ModelContainerFactory.shared)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: NightEngine.shared.resumeTrackingIfNeeded()
            case .background: NightEngine.shared.flush()
            default: break
            }
        }
    }
}
