import CoreLocation
import Observation
import os

@MainActor
protocol LocationProviding: AnyObject {
    var isAuthorizationDenied: Bool { get }
    func startUpdates(_ handler: @escaping @MainActor (LocationUpdate) -> Void)
    func stopUpdates()
    /// A fresh precise one-shot fix, or `nil` if none arrives within `timeout`.
    func currentFix(timeout: Duration) async -> LocationFix?
}

@MainActor
@Observable
final class LocationService: NSObject, LocationProviding {
    private(set) var authorization: CLAuthorizationStatus

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var serviceSession: CLServiceSession?
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.bgergo03.barhop", category: "Location")

    /// Accuracy a one-shot fix must reach to count as precise.
    nonisolated private static let preciseAccuracy: CLLocationAccuracy = 50

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAuthorizationDenied: Bool { authorization == .denied || authorization == .restricted }

    func startUpdates(_ handler: @escaping @MainActor (LocationUpdate) -> Void) {
        stopUpdates()
        // When-In-Use only (SPEC §2). The background activity session keeps updates
        // flowing while backgrounded and shows the blue location indicator.
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundSession = CLBackgroundActivitySession()
        updatesTask = Task { [logger] in
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if Task.isCancelled { break }
                    handler(LocationUpdate(fix: update.location.map(LocationFix.init), isStationary: update.stationary))
                }
            } catch {
                logger.error("Live updates ended: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func stopUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
    }

    func currentFix(timeout: Duration) async -> LocationFix? {
        guard !isAuthorizationDenied else { return nil }
        return await withTaskGroup(of: LocationFix?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        guard let location = update.location,
                              location.horizontalAccuracy >= 0,
                              location.horizontalAccuracy <= Self.preciseAccuracy else { continue }
                        return LocationFix(location)
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}
