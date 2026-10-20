import Foundation
@testable import Barhop

@MainActor
final class FakeReminders: StillOutReminding {
    var onResponse: (@MainActor (StillOutResponse, UUID) -> Void)?
    private(set) var scheduled: [UUID: Date] = [:]
    private(set) var authorizationRequests = 0

    func requestAuthorization() {
        authorizationRequests += 1
    }

    func schedule(nightID: UUID, at date: Date) {
        scheduled[nightID] = date
    }

    func cancel(nightID: UUID) {
        scheduled[nightID] = nil
    }

    func respond(_ response: StillOutResponse, nightID: UUID) {
        onResponse?(response, nightID)
    }
}

extension AutoClose {
    /// Test fixtures are dated around 1970, so the real wall clock would close them at once.
    static let neverInTests = AutoClose(interval: 200 * 365 * 24 * 3600, grace: 0)
}
