import Foundation
@testable import Barhop

@MainActor
final class FakeLocationProvider: LocationProviding {
    var isAuthorizationDenied = false
    var fix: LocationFix?
    private(set) var handler: ((LocationUpdate) -> Void)?
    private(set) var startCount = 0

    var isRunning: Bool { handler != nil }

    func startUpdates(_ handler: @escaping @MainActor (LocationUpdate) -> Void) {
        startCount += 1
        self.handler = handler
    }

    func stopUpdates() {
        handler = nil
    }

    func currentFix(timeout: Duration) async -> LocationFix? {
        fix
    }

    func send(_ fix: LocationFix, stationary: Bool = false) {
        handler?(LocationUpdate(fix: fix, isStationary: stationary))
    }
}
