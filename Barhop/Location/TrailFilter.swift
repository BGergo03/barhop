import Foundation

/// Turns raw location updates into the trail points worth keeping (SPEC §6).
struct TrailFilter {
    static let maxAccuracy: Double = 100
    static let minDistance: Double = 50
    static let minInterval: TimeInterval = 5 * 60
    static let gapThreshold: TimeInterval = 10 * 60

    struct AcceptedPoint: Equatable {
        var fix: LocationFix
        var segment: Int
    }

    private(set) var segment: Int
    private let notBefore: Date?
    private var lastAccepted: LocationFix?
    private var lastReceivedAt: Date?
    private var pausedWhileStationary = false

    /// - Parameters:
    ///   - notBefore: the night's start; earlier fixes are dropped.
    ///   - lastPoint: the night's latest recorded point, if any.
    ///   - startNewSegment: true after a recovery restart (SPEC §5).
    init(notBefore: Date? = nil, resumingFrom lastPoint: AcceptedPoint? = nil, startNewSegment: Bool = false) {
        self.notBefore = notBefore
        guard let lastPoint else {
            segment = 0
            return
        }
        if startNewSegment {
            segment = lastPoint.segment + 1
        } else {
            segment = lastPoint.segment
            lastAccepted = lastPoint.fix
            lastReceivedAt = lastPoint.fix.timestamp
        }
    }

    mutating func process(_ update: LocationUpdate) -> [AcceptedPoint] {
        guard let fix = update.fix else { return [] }
        // Core Location opens with its last cached fix, which can predate the night.
        if let notBefore, fix.timestamp < notBefore { return [] }
        var accepted: [AcceptedPoint] = []

        if let lastReceivedAt, fix.timestamp.timeIntervalSince(lastReceivedAt) > Self.gapThreshold {
            if pausedWhileStationary, let anchor = lastAccepted {
                // Silence was Core Location pausing because we stood still (e.g. inside a bar),
                // not a tracking gap. Record that we were still there right up to now so stop
                // detection sees the whole stay.
                var hold = anchor
                hold.timestamp = fix.timestamp.addingTimeInterval(-1)
                lastAccepted = hold
                accepted.append(AcceptedPoint(fix: hold, segment: segment))
            } else {
                segment += 1
                lastAccepted = nil
            }
        }
        lastReceivedAt = fix.timestamp
        pausedWhileStationary = update.isStationary

        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= Self.maxAccuracy else { return accepted }
        if let last = lastAccepted,
           fix.distance(to: last) < Self.minDistance,
           fix.timestamp.timeIntervalSince(last.timestamp) < Self.minInterval {
            return accepted
        }
        lastAccepted = fix
        accepted.append(AcceptedPoint(fix: fix, segment: segment))
        return accepted
    }
}
