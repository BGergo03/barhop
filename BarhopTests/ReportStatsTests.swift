import CoreLocation
import Foundation
import Testing
@testable import Barhop

struct ReportStatsTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    func beer(_ minutes: Double) -> ReportStats.Drink {
        ReportStats.Drink(timestamp: start.addingTimeInterval(minutes * 60), payload: .beer)
    }

    func stats(minutes: Double, drinks: [ReportStats.Drink] = [], stays: [ReportStats.Stay] = []) -> ReportStats {
        ReportStats(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), drinks: drinks, segments: [], stays: stays)
    }

    @Test func zeroBeerNight() {
        let report = stats(minutes: 90)
        #expect(report.beers == 0)
        #expect(report.liters == 0)
        #expect(report.pace == 0)
        #expect(report.longestGap == nil)
        #expect(report.distance == 0)
        #expect(report.venues.isEmpty)
    }

    @Test func paceNeedsAMinute() {
        #expect(stats(minutes: 0.9, drinks: [beer(0)]).pace == nil)
        #expect(stats(minutes: 30, drinks: [beer(0)]).pace == 2)
    }

    @Test func longestGapNeedsTwoBeers() throws {
        #expect(stats(minutes: 60, drinks: [beer(10)]).longestGap == nil)
        // Unsorted input, as entries come out of SwiftData.
        let gap = try #require(stats(minutes: 60, drinks: [beer(50), beer(5), beer(20)]).longestGap)
        #expect(abs(gap - 30 * 60) < 0.001)
    }

    @Test func litersComeFromPayload() {
        let small = ReportStats.Drink(timestamp: start, payload: DrinkPayload(drinkType: "beer", volumeMl: 330))
        #expect(stats(minutes: 60, drinks: [beer(0), small]).liters == 0.83)
    }

    @Test func driftInsideAVenueIsNotWalking() {
        // Walk 100 m north, sit 30 min with fixes jittering 20 m, walk 100 m on.
        let fixes = [
            testFix(0), testFix(60, north: 100),
            testFix(360, north: 120), testFix(660, north: 100), testFix(960, north: 120), testFix(1860, north: 100),
            testFix(1920, north: 200),
        ]
        let bar = testFix(0, north: 110)
        let stay = ReportStats.Stay(
            id: UUID(), name: "Bar", latitude: bar.latitude, longitude: bar.longitude,
            arrivedAt: fixes[1].timestamp, leftAt: fixes[5].timestamp
        )
        let report = ReportStats(
            startedAt: fixes[0].timestamp,
            endedAt: fixes[6].timestamp,
            drinks: [],
            segments: [fixes],
            stays: [stay]
        )
        #expect(abs(report.distance - 200) < 1)
    }

    @Test func openVenueLeftBehindDoesNotSwallowTheWalk() {
        // A beer logged while passing through opens a venue that never closes:
        // fixes beyond its radius are still walking.
        let fixes = [testFix(0), testFix(60, north: 100), testFix(120, north: 200), testFix(180, north: 300)]
        let stay = ReportStats.Stay(
            id: UUID(), name: "Corner", latitude: fixes[0].latitude, longitude: fixes[0].longitude,
            arrivedAt: fixes[0].timestamp, leftAt: nil
        )
        let report = ReportStats(
            startedAt: fixes[0].timestamp,
            endedAt: fixes[3].timestamp,
            drinks: [],
            segments: [fixes],
            stays: [stay]
        )
        #expect(abs(report.distance - 300) < 1)
    }

    @Test func venuesOrderedWithOpenOneCountingToEnd() {
        let late = ReportStats.Stay(id: UUID(), name: "B", latitude: 47.5, longitude: 19.06, arrivedAt: start.addingTimeInterval(3600), leftAt: nil)
        let early = ReportStats.Stay(id: UUID(), name: "A", latitude: 47.5, longitude: 19.06, arrivedAt: start, leftAt: start.addingTimeInterval(1800))
        let report = stats(minutes: 90, stays: [late, early])
        #expect(report.venues.map(\.name) == ["A", "B"])
        #expect(report.venues.map(\.timeSpent) == [1800, 1800])
    }
}

/// The M4 acceptance check: the GPX crawl night, driven through the engine, against numbers
/// worked out by hand from Simulator/BudapestCrawl.gpx.
@MainActor
struct CrawlReportTests {
    let container = TestSupport.makeContainer()
    let location = FakeLocationProvider()
    let namer = FakeVenueNamer()

    static func time(_ hhmmss: String) -> Date {
        try! Date("2026-10-24T\(hhmmss)Z", strategy: .iso8601)
    }

    @Test func crawlNightMatchesHandCalculation() async throws {
        let engine = NightEngine(context: container.mainContext, location: location, namer: namer)
        let night = engine.startNight(at: Self.time("18:55:00"))

        // One beer at Lámpás, Szimpla Kert and Doboz, two at Mazel Tov.
        var beers = ["19:05:00", "19:35:00", "20:20:00", "20:45:00", "21:00:00"].map(Self.time)
        for fix in CrawlReplayTests.replay(try CrawlReplayTests.loadCrawl()) {
            if let next = beers.first, fix.timestamp >= next {
                beers.removeFirst()
                location.fix = fix
                engine.logBeer(at: next)
                await TestSupport.settle()
            }
            location.send(fix)
        }
        engine.endNight(night, at: Self.time("21:10:00"))

        let stats = ReportStats(night: night)

        // 18:55 → 21:10
        #expect(stats.duration == 2 * 3600 + 15 * 60)
        #expect(stats.beers == 5)
        #expect(stats.liters == 2.5)
        // 5 beers / 2.25 h
        #expect(abs(try #require(stats.pace) - 2.22) < 0.01)
        // 19:35 → 20:20
        #expect(abs(try #require(stats.longestGap) - 45 * 60) < 0.001)

        // Drift inside the bars doesn't count, so the distance lies between the straight lines from
        // bar to bar (223 m + 263 m + 281 m = 767 m) and the GPX walking legs (234 m + 300 m + 294 m
        // = 828 m): the filter keeps a fix every 50 m, which cuts corners. A few meters of slack
        // because venue centers are centroids, not the exact bar coordinates.
        #expect((757...828).contains(stats.distance), "distance \(stats.distance)")

        // Stays from the GPX dwells; the last one runs until the night ends.
        let expected: [(arrived: String, minutes: Double)] = [
            ("19:00:00", 25),         // Lámpás 19:00–19:25
            ("19:29:00", 39),         // Szimpla Kert 19:29–20:08
            ("20:12:40", 19),         // Doboz 20:12:40–20:31:40
            ("20:36:20", 33 + 40 / 60), // Mazel Tov 20:36:20–21:10
        ]
        try #require(stats.venues.count == expected.count)
        for (venue, hand) in zip(stats.venues, expected) {
            // Arrival is the cluster's first point and leaving its last point inside the radius,
            // which can be a walking fix or two either side of the door.
            #expect(abs(venue.arrivedAt.timeIntervalSince(Self.time(hand.arrived))) < 180, "\(venue.name) arrival")
            #expect(abs(venue.timeSpent - hand.minutes * 60) < 4 * 60, "\(venue.name) \(venue.timeSpent / 60) min")
        }
        #expect(night.entries.allSatisfy { $0.venue != nil })
        #expect(Set(night.entries.compactMap(\.venue?.id)).count == 4)
    }
}
