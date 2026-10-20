import Foundation
import SwiftData
import Testing
@testable import Barhop

@MainActor
struct NightEngineTests {
    let container = TestSupport.makeContainer()
    let location = FakeLocationProvider()
    let namer = FakeVenueNamer()
    let liveActivity = FakeLiveActivity()
    var engine: NightEngine { NightEngine(context: container.mainContext, location: location, namer: namer, liveActivity: liveActivity) }

    @Test func loggingWithoutActiveNightStartsOne() throws {
        let engine = engine
        #expect(engine.activeNight == nil)
        engine.logBeer()
        let night = try #require(engine.activeNight)
        #expect(night.beerCount == 1)
        #expect(night.liters == 0.5)
    }

    @Test func onlyOneActiveNight() {
        let engine = engine
        let first = engine.startNight()
        let second = engine.startNight()
        #expect(first.id == second.id)
    }

    @Test func lastActivityTracksLatestEntry() throws {
        let engine = engine
        let start = Date(timeIntervalSince1970: 1_000_000)
        let night = engine.startNight(at: start)
        let entry = engine.logBeer(at: start.addingTimeInterval(600))
        #expect(night.lastActivityAt == entry.timestamp)

        engine.deleteEntry(entry)
        #expect(night.lastActivityAt == start)
    }

    @Test func editedTimeIsClampedToNight() {
        let engine = engine
        let start = Date(timeIntervalSince1970: 1_000_000)
        let night = engine.startNight(at: start)
        let entry = engine.logBeer(at: start.addingTimeInterval(60))
        engine.endNight(night, at: start.addingTimeInterval(3600))

        engine.editEntryTime(entry, to: start.addingTimeInterval(-600))
        #expect(entry.timestamp == start)
        engine.editEntryTime(entry, to: start.addingTimeInterval(7200))
        #expect(entry.timestamp == start.addingTimeInterval(3600))
    }

    @Test func endingNightClearsActive() {
        let engine = engine
        let night = engine.startNight()
        engine.endNight(night)
        #expect(engine.activeNight == nil)
        #expect(night.endReason == .manual)
    }

    @Test func deletingNightCascadesToEntries() throws {
        let engine = engine
        engine.logBeer()
        let night = try #require(engine.activeNight)
        engine.endNight(night)
        engine.deleteNight(night)
        let entries = try container.mainContext.fetch(FetchDescriptor<Entry>())
        #expect(entries.isEmpty)
    }

    @Test func trackingRunsOnlyWhileNightIsActive() {
        let engine = engine
        let night = engine.startNight()
        #expect(location.isRunning)
        engine.endNight(night)
        #expect(!location.isRunning)
    }

    @Test func acceptedFixesBecomeTrailPoints() throws {
        let engine = engine
        let start = Date(timeIntervalSince1970: 1_000_000)
        let night = engine.startNight(at: start)
        location.send(LocationFix(timestamp: start, latitude: 47.4970, longitude: 19.0633, horizontalAccuracy: 10))
        location.send(LocationFix(timestamp: start.addingTimeInterval(20), latitude: 47.4971, longitude: 19.0633, horizontalAccuracy: 10)) // ~11 m: dropped
        location.send(LocationFix(timestamp: start.addingTimeInterval(60), latitude: 47.4980, longitude: 19.0633, horizontalAccuracy: 10))
        #expect(night.trailPoints.count == 2)
    }

    @Test func resumingAfterRelaunchStartsNewSegment() throws {
        let engine = engine
        let start = Date(timeIntervalSince1970: 1_000_000)
        let night = engine.startNight(at: start)
        location.send(LocationFix(timestamp: start, latitude: 47.4970, longitude: 19.0633, horizontalAccuracy: 10))
        #expect(night.trailPoints.count == 1)

        // Simulate a relaunch: a fresh engine over the same store.
        let relaunched = NightEngine(context: container.mainContext, location: location, namer: namer, liveActivity: liveActivity)
        relaunched.resumeTrackingIfNeeded()
        location.send(LocationFix(timestamp: start.addingTimeInterval(30), latitude: 47.4990, longitude: 19.0633, horizontalAccuracy: 10))
        #expect(Set(night.trailPoints.map(\.segment)) == [0, 1])
    }

    @Test func deletingEntryBeforeFixArrivesIsSafe() async {
        let engine = engine
        let entry = engine.logBeer()
        engine.deleteEntry(entry)
        await TestSupport.settle()
        #expect(engine.activeNight?.entries.isEmpty == true)
    }

    @Test func loggedBeerGetsFreshFix() async throws {
        let engine = engine
        location.fix = LocationFix(timestamp: .now, latitude: 47.5, longitude: 19.06, horizontalAccuracy: 8)
        let entry = engine.logBeer()
        await TestSupport.settle()
        #expect(entry.latitude == 47.5)
        #expect(entry.horizontalAccuracy == 8)
    }
}
