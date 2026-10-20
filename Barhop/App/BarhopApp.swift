import AppIntents
import SwiftData
import SwiftUI

@main
struct BarhopApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Intents from the Live Activity run in this process and reach the engine through this.
        let handler: any NightIntentHandling = NightEngine.shared
        AppDependencyManager.shared.add(dependency: handler)
        // Runs on background relaunches by Core Location too, where no scene becomes active.
        NightEngine.shared.resumeTrackingIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(NightEngine.shared)
                .preferredColorScheme(Theme.colorScheme)
                .tint(Theme.Palette.accent)
                .fontDesign(Theme.fontDesign)
        }
        .modelContainer(ModelContainerFactory.shared)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                NightEngine.shared.resumeTrackingIfNeeded()
                NightEngine.shared.backfillPlacesIfNeeded()
            case .background: NightEngine.shared.flush()
            default: break
            }
        }
    }
}
