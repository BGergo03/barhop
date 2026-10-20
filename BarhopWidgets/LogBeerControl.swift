import AppIntents
import SwiftUI
import WidgetKit

/// Control Center "+1 Beer" (SPEC §8). `LogBeerIntent` is a `LiveActivityIntent`, so it is
/// expected to run in the app process like the Live Activity buttons; verify on device.
struct LogBeerControl: ControlWidget {
    static let kind = "com.bgergo03.barhop.log-beer"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogBeerIntent()) {
                Label("+1 Beer", systemImage: "mug.fill")
            }
        }
        .displayName("+1 Beer")
        .description("Logs a beer, starting a night if none is active.")
    }
}
