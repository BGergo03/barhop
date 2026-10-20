import Foundation
import SwiftData
@testable import Barhop

@MainActor
enum TestSupport {
    /// The engine attaches entry locations and venue names in tasks that can outlive a test.
    /// The app's container lives for the whole process, so keep test containers alive too.
    private static var retainedContainers: [ModelContainer] = []

    static func makeContainer() -> ModelContainer {
        let container = ModelContainerFactory.make(inMemory: true)
        retainedContainers.append(container)
        return container
    }

    /// Lets detached engine tasks (fixes, naming) run to completion against the fakes.
    static func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }
}

/// A fix `northMeters` / `eastMeters` from a Budapest origin, `seconds` after a fixed start.
func testFix(_ seconds: TimeInterval, north northMeters: Double = 0, east eastMeters: Double = 0, accuracy: Double = 10) -> LocationFix {
    LocationFix(
        timestamp: Date(timeIntervalSince1970: 1_000_000 + seconds),
        latitude: 47.5 + northMeters / 111_000,
        longitude: 19.06 + eastMeters / (111_000 * cos(47.5 * .pi / 180)),
        horizontalAccuracy: accuracy
    )
}
