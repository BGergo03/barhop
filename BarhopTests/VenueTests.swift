import Foundation
import SwiftData
import Testing
@testable import Barhop

@MainActor
struct VenueTests {
    let container = TestSupport.makeContainer()
    let location = FakeLocationProvider()
    let namer = FakeVenueNamer()

    func makeEngine() -> NightEngine {
        NightEngine(context: container.mainContext, location: location, namer: namer)
    }

    func candidate(_ name: String) -> VenueCandidate {
        VenueCandidate(name: name, latitude: 47.5, longitude: 19.06, distance: 10)
    }

    @Test func beerOutsideVenueCreatesProvisionalVenue() async throws {
        let engine = makeEngine()
        namer.candidates = [candidate("Szimpla Kert")]
        location.fix = testFix(0)
        let entry = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()

        let venue = try #require(entry.venue)
        #expect(venue.name == "Szimpla Kert")
        #expect(venue.nameSource == .auto)
        #expect(venue.leftAt == nil)
    }

    @Test func secondBeerNearbyJoinsSameVenue() async throws {
        let engine = makeEngine()
        location.fix = testFix(0)
        let first = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()
        location.fix = testFix(600, north: 30)
        let second = engine.logBeer(at: testFix(600).timestamp)
        await TestSupport.settle()

        #expect(first.venue != nil)
        #expect(first.venue?.id == second.venue?.id)
        #expect(engine.activeNight?.venues.count == 1)
    }

    @Test func beerFarAwayClosesPreviousVenue() async throws {
        let engine = makeEngine()
        location.fix = testFix(0)
        let first = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()
        location.fix = testFix(1800, north: 300)
        let second = engine.logBeer(at: testFix(1800).timestamp)
        await TestSupport.settle()

        let firstVenue = try #require(first.venue)
        #expect(firstVenue.leftAt == testFix(1800).timestamp)
        #expect(second.venue?.id != firstVenue.id)
        #expect(second.venue?.leftAt == nil)
    }

    @Test func detectedStayMergesIntoProvisionalVenue() async throws {
        let engine = makeEngine()
        let night = engine.startNight(at: testFix(0).timestamp)
        // Lingering a few minutes before the first beer...
        for minute in 0...5 { location.send(testFix(Double(minute) * 60, north: 10)) }
        location.fix = testFix(6 * 60)
        engine.logBeer(at: testFix(6 * 60).timestamp)
        await TestSupport.settle()
        // ...and staying on: points every 5 min (the trail filter's interval) for 30 min.
        for minute in stride(from: 10, through: 40, by: 5) {
            location.send(testFix(Double(minute) * 60, north: -15))
        }

        #expect(night.venues.count == 1)
        let venue = try #require(night.venues.first)
        #expect(venue.arrivedAt == testFix(0).timestamp)
    }

    @Test func walkingAwayClosesVenueAtLastPointInside() async throws {
        let engine = makeEngine()
        let night = engine.startNight(at: testFix(0).timestamp)
        for minute in stride(from: 0, through: 20, by: 5) { location.send(testFix(Double(minute) * 60)) }
        location.send(testFix(21 * 60, north: 100))
        location.send(testFix(22 * 60, north: 160))

        let venue = try #require(night.venues.first)
        #expect(venue.leftAt == testFix(20 * 60).timestamp)
        #expect(night.currentVenue == nil)
    }

    @Test func addressIsFallbackName() async throws {
        let engine = makeEngine()
        namer.address = "Kazinczy utca 14"
        location.fix = testFix(0)
        let entry = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()

        #expect(entry.venue?.name == "Kazinczy utca 14")
        #expect(entry.venue?.nameSource == .address)
    }

    @Test func userNameIsNeverOverwritten() async throws {
        let engine = makeEngine()
        let night = engine.startNight(at: testFix(0).timestamp)
        location.fix = testFix(0)
        let entry = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()
        let venue = try #require(entry.venue)
        engine.renameVenue(venue, to: "Our spot")

        // A confirmed stay at the same place would normally re-run auto naming.
        namer.candidates = [candidate("Szimpla Kert")]
        for minute in stride(from: 5, through: 30, by: 5) { location.send(testFix(Double(minute) * 60)) }
        await TestSupport.settle()

        #expect(night.venues.count == 1)
        #expect(venue.name == "Our spot")
        #expect(venue.nameSource == .user)
    }

    @Test func endingNightClosesOpenVenue() async throws {
        let engine = makeEngine()
        location.fix = testFix(0)
        let entry = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()
        let night = try #require(entry.night)
        engine.endNight(night, at: testFix(3600).timestamp)

        #expect(entry.venue?.leftAt == testFix(3600).timestamp)
    }
}
