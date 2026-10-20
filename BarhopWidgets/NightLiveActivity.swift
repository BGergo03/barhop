import ActivityKit
import SwiftUI
import WidgetKit

/// Placeholder so the extension builds; the real Lock Screen and
/// Dynamic Island UI is built in M5.
struct NightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightActivityAttributes.self) { context in
            Text("🍺 \(context.state.beerCount)")
                .font(Theme.Typography.headline)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("🍺 \(context.state.beerCount)")
                }
            } compactLeading: {
                Text("🍺")
            } compactTrailing: {
                Text(context.state.beerCount, format: .number)
            } minimal: {
                Text(context.state.beerCount, format: .number)
            }
        }
    }
}
