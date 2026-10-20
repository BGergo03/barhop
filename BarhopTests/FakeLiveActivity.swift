import Foundation
@testable import Barhop

@MainActor
final class FakeLiveActivity: LiveActivityControlling {
    private(set) var state: NightActivityAttributes.ContentState?
    private(set) var nightID: UUID?

    var isRunning: Bool { state != nil }

    func show(_ state: NightActivityAttributes.ContentState, nightID: UUID, startedAt: Date) {
        self.state = state
        self.nightID = nightID
    }

    func end() {
        state = nil
        nightID = nil
    }
}
