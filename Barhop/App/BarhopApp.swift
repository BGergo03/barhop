import SwiftData
import SwiftUI

@main
struct BarhopApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(NightEngine.shared)
                .preferredColorScheme(Theme.colorScheme)
        }
        .modelContainer(ModelContainerFactory.shared)
    }
}
