import Foundation

/// Detects stops (venues) from accepted trail points (SPEC §6): the trail stays within
/// `radius` of its running centroid for at least `minimumStay`.
struct StopDetector {
    static let radius: Double = 75
    static let minimumStay: TimeInterval = 15 * 60

    enum Event: Equatable {
        /// A stay reached `minimumStay`. `at` is the first point of the cluster.
        case arrived(center: Center, at: Date)
        /// The confirmed stop's centroid moved as more points came in.
        case moved(center: Center)
        /// Left the confirmed stop. `at` is the last point inside the radius.
        case left(at: Date)
    }

    struct Center: Equatable {
        var latitude: Double
        var longitude: Double
    }

    private var cluster: [LocationFix] = []
    private var center: LocationFix?
    private var isConfirmed = false
    /// A single fix outside the radius isn't enough to leave: it may be GPS noise
    /// (fixes up to 100 m accuracy are kept). Two in a row are.
    private var pendingOutside: LocationFix?

    mutating func process(_ fix: LocationFix) -> [Event] {
        guard let center else {
            start(with: fix)
            return []
        }
        if fix.distance(to: center) <= Self.radius {
            pendingOutside = nil
            add(fix)
            return confirmIfStayedLongEnough()
        }
        guard let pending = pendingOutside else {
            pendingOutside = fix
            return []
        }
        var events: [Event] = []
        if isConfirmed, let lastInside = cluster.last {
            events.append(.left(at: lastInside.timestamp))
        }
        start(with: pending)
        events += process(fix)
        return events
    }

    /// Marks the current position as a stop without waiting for `minimumStay`,
    /// used for provisional venues created by logging a beer.
    /// - Returns: when the stay started (earlier than `fix` if we were already lingering here).
    mutating func anchor(at fix: LocationFix) -> Date {
        pendingOutside = nil
        if let center, fix.distance(to: center) <= Self.radius, let first = cluster.first {
            isConfirmed = true
            return first.timestamp
        }
        start(with: fix)
        isConfirmed = true
        return fix.timestamp
    }

    private mutating func start(with fix: LocationFix) {
        cluster = [fix]
        center = fix
        isConfirmed = false
        pendingOutside = nil
    }

    private mutating func add(_ fix: LocationFix) {
        cluster.append(fix)
        guard var center else { return }
        let count = Double(cluster.count)
        center.latitude += (fix.latitude - center.latitude) / count
        center.longitude += (fix.longitude - center.longitude) / count
        self.center = center
    }

    private mutating func confirmIfStayedLongEnough() -> [Event] {
        guard let center, let first = cluster.first, let last = cluster.last else { return [] }
        let centerValue = Center(latitude: center.latitude, longitude: center.longitude)
        if isConfirmed { return [.moved(center: centerValue)] }
        guard last.timestamp.timeIntervalSince(first.timestamp) >= Self.minimumStay else { return [] }
        isConfirmed = true
        return [.arrived(center: centerValue, at: first.timestamp)]
    }
}
