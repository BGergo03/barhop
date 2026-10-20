import Foundation
import Testing
@testable import Barhop

struct StopDetectorTests {
    /// Feeds a stay of `minutes` around the origin (one fix a minute, wobbling ±20 m).
    func dwell(_ detector: inout StopDetector, from start: TimeInterval = 0, minutes: Int) -> [StopDetector.Event] {
        (0...minutes).flatMap { minute in
            detector.process(testFix(start + Double(minute) * 60, north: minute.isMultiple(of: 2) ? 20 : -20))
        }
    }

    @Test func fifteenMinuteStayIsAStop() {
        var detector = StopDetector()
        let events = dwell(&detector, minutes: 15)
        #expect(events.count == 1)
        guard case let .arrived(center, at) = events.first else {
            Issue.record("expected arrival")
            return
        }
        #expect(at == testFix(0).timestamp)
        #expect(abs(center.latitude - 47.5) < 0.0002)
    }

    @Test func shorterStayIsNotAStop() {
        var detector = StopDetector()
        #expect(dwell(&detector, minutes: 14).isEmpty)
    }

    @Test func walkingPastIsNotAStop() {
        var detector = StopDetector()
        let events = (0..<60).flatMap { step in
            detector.process(testFix(Double(step) * 40, north: Double(step) * 55))
        }
        #expect(events.isEmpty)
    }

    @Test func leavingNeedsTwoFixesOutside() {
        var detector = StopDetector()
        _ = dwell(&detector, minutes: 20)
        // One noisy fix outside, then back inside: still there.
        #expect(detector.process(testFix(21 * 60, north: 150)).isEmpty)
        let backInside = detector.process(testFix(22 * 60))
        #expect(backInside.count == 1)
        #expect(!backInside.contains(.left(at: testFix(20 * 60).timestamp)))
        // Walking away for real.
        #expect(detector.process(testFix(23 * 60, north: 120)).isEmpty)
        let events = detector.process(testFix(23 * 60 + 40, north: 180))
        #expect(events == [.left(at: testFix(22 * 60).timestamp)])
    }

    @Test func anchoredStopEmitsLeftButNotArrived() {
        var detector = StopDetector()
        let arrivedAt = detector.anchor(at: testFix(0))
        #expect(arrivedAt == testFix(0).timestamp)
        let stay = dwell(&detector, from: 60, minutes: 20)
        #expect(!stay.contains { if case .arrived = $0 { true } else { false } })
        _ = detector.process(testFix(30 * 60, north: 200))
        let events = detector.process(testFix(31 * 60, north: 260))
        #expect(events.first == .left(at: testFix(21 * 60).timestamp))
    }

    @Test func anchoringInsideACandidateKeepsItsStart() {
        var detector = StopDetector()
        _ = dwell(&detector, minutes: 5)
        #expect(detector.anchor(at: testFix(6 * 60, north: 10)) == testFix(0).timestamp)
    }
}
