import Foundation
import Testing
@testable import Barhop

struct TrailFilterTests {
    let start = Date(timeIntervalSince1970: 1_000_000)
    /// ~111 m per 0.001° of latitude.
    func fix(_ seconds: TimeInterval, northMeters: Double = 0, accuracy: Double = 10) -> LocationFix {
        LocationFix(
            timestamp: start.addingTimeInterval(seconds),
            latitude: 47.5 + northMeters / 111_000,
            longitude: 19.06,
            horizontalAccuracy: accuracy
        )
    }

    @Test func dropsInaccurateFixes() {
        var filter = TrailFilter()
        #expect(filter.process(LocationUpdate(fix: fix(0, accuracy: 150))).isEmpty)
        #expect(filter.process(LocationUpdate(fix: fix(0, accuracy: -1))).isEmpty)
        #expect(filter.process(LocationUpdate(fix: fix(0, accuracy: 100))).count == 1)
    }

    @Test func acceptsAfterDistanceOrInterval() {
        var filter = TrailFilter()
        #expect(filter.process(LocationUpdate(fix: fix(0))).count == 1)
        #expect(filter.process(LocationUpdate(fix: fix(60, northMeters: 30))).isEmpty)
        #expect(filter.process(LocationUpdate(fix: fix(90, northMeters: 55))).count == 1)
        #expect(filter.process(LocationUpdate(fix: fix(90 + 299, northMeters: 60))).isEmpty)
        #expect(filter.process(LocationUpdate(fix: fix(90 + 300, northMeters: 60))).count == 1)
    }

    @Test func gapStartsNewSegment() {
        var filter = TrailFilter()
        _ = filter.process(LocationUpdate(fix: fix(0)))
        _ = filter.process(LocationUpdate(fix: fix(300)))
        let afterGap = filter.process(LocationUpdate(fix: fix(300 + 601, northMeters: 10)))
        #expect(afterGap.map(\.segment) == [1])
    }

    @Test func inaccurateUpdatesStillCountAsTracking() {
        var filter = TrailFilter()
        _ = filter.process(LocationUpdate(fix: fix(0)))
        _ = filter.process(LocationUpdate(fix: fix(500, accuracy: 500)))
        let next = filter.process(LocationUpdate(fix: fix(1000, northMeters: 60)))
        #expect(next.map(\.segment) == [0])
    }

    @Test func stationaryPauseIsNotAGap() {
        var filter = TrailFilter()
        _ = filter.process(LocationUpdate(fix: fix(0)))
        _ = filter.process(LocationUpdate(fix: fix(60), isStationary: true))
        // Updates resume 30 min later as we walk out.
        let resumed = filter.process(LocationUpdate(fix: fix(60 + 1800, northMeters: 80)))
        #expect(resumed.count == 2)
        #expect(resumed.map(\.segment) == [0, 0])
        #expect(resumed[0].fix.latitude == fix(0).latitude)
        #expect(resumed[0].fix.timestamp == fix(60 + 1799).timestamp)
    }

    @Test func resumingContinuesOrStartsSegment() {
        let last = TrailFilter.AcceptedPoint(fix: fix(0), segment: 2)
        var continuing = TrailFilter(resumingFrom: last)
        #expect(continuing.process(LocationUpdate(fix: fix(30, northMeters: 10))).isEmpty)

        var recovered = TrailFilter(resumingFrom: last, startNewSegment: true)
        #expect(recovered.process(LocationUpdate(fix: fix(30, northMeters: 10))).map(\.segment) == [3])
    }
}

struct TrailGeometryTests {
    func point(_ seconds: TimeInterval, northMeters: Double, segment: Int) -> TrailPoint {
        TrailPoint(
            timestamp: Date(timeIntervalSince1970: seconds),
            latitude: 47.5 + northMeters / 111_000,
            longitude: 19.06,
            horizontalAccuracy: 10,
            segment: segment
        )
    }

    @Test func distanceExcludesGapsBetweenSegments() {
        let points = [
            point(0, northMeters: 0, segment: 0),
            point(60, northMeters: 100, segment: 0),
            point(2000, northMeters: 1100, segment: 1), // 1 km jump across the gap
            point(2060, northMeters: 1200, segment: 1),
        ].shuffled()
        let distance = TrailGeometry.walkedDistance(points)
        #expect(abs(distance - 200) < 2)
        #expect(TrailGeometry.segments(points).map(\.count) == [2, 2])
        #expect(TrailGeometry.gaps(between: TrailGeometry.segments(points)).count == 1)
    }
}
