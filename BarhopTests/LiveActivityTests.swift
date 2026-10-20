import Foundation
import Testing
@testable import Barhop

@MainActor
struct LiveActivityTests {
    let container = TestSupport.makeContainer()
    let location = FakeLocationProvider()
    let namer = FakeVenueNamer()
    let liveActivity = FakeLiveActivity()
    let reminders = FakeReminders()

    func makeEngine() -> NightEngine {
        NightEngine(context: container.mainContext, location: location, namer: namer, liveActivity: liveActivity, reminders: reminders, autoClose: { .neverInTests })
    }

    @Test func activityMirrorsNightAndEndsWithIt() throws {
        let engine = makeEngine()
        let night = engine.startNight()
        #expect(liveActivity.nightID == night.id)
        #expect(liveActivity.state?.beerCount == 0)

        engine.logBeer()
        engine.logBeer()
        #expect(liveActivity.state?.beerCount == 2)

        engine.endNight(night)
        #expect(!liveActivity.isRunning)
    }

    @Test func loggingOffersUndoForThatEntry() throws {
        let engine = makeEngine()
        let entry = engine.logBeer()
        let state = try #require(liveActivity.state)
        #expect(state.lastEntryID == entry.id)
        #expect(try #require(state.undoUntil) > .now)
    }

    @Test func undoRowClearsOnceExpired() throws {
        let engine = makeEngine()
        engine.logBeer()
        engine.refreshLiveActivity(now: .now.addingTimeInterval(NightEngine.undoOfferDuration))
        #expect(liveActivity.state?.undoUntil == nil)
        #expect(liveActivity.state?.lastEntryID == nil)
    }

    @Test func threeBeersAndOneUndoLeavesTwo() async throws {
        let engine = makeEngine()
        for _ in 0..<3 { await engine.logBeerFromIntent() }
        engine.undoLastEntryFromIntent(entryID: liveActivity.state?.lastEntryID)
        #expect(engine.activeNight?.beerCount == 2)
        #expect(liveActivity.state?.beerCount == 2)
        #expect(liveActivity.state?.undoUntil == nil)
    }

    @Test func undoRemovesOnlyTheLastLoggedEntry() throws {
        let engine = makeEngine()
        let start = Date.now
        let first = engine.logBeer(at: start)
        engine.logBeer(at: start.addingTimeInterval(5))
        // Editing an older entry's time to be the latest doesn't make it "last logged".
        engine.editEntryTime(first, to: start.addingTimeInterval(30))

        #expect(engine.undoLastEntry(now: start.addingTimeInterval(10)))
        let night = try #require(engine.activeNight)
        #expect(night.entries.map(\.id) == [first.id])
    }

    @Test func undoIsANoOpAfterAMinute() throws {
        let engine = makeEngine()
        let entry = engine.logBeer()
        #expect(!engine.undoLastEntry(now: entry.createdAt.addingTimeInterval(NightEngine.undoWindow)))
        #expect(engine.activeNight?.beerCount == 1)
    }

    @Test func undoIgnoresAStaleEntryID() throws {
        let engine = makeEngine()
        let first = engine.logBeer()
        engine.logBeer()
        #expect(!engine.undoLastEntry(expectedID: first.id))
        #expect(engine.activeNight?.beerCount == 2)
    }

    @Test func undoWithoutActiveNightDoesNothing() {
        let engine = makeEngine()
        #expect(!engine.undoLastEntry())
    }

    @Test func intentLogStartsNightWithLocation() async throws {
        let engine = makeEngine()
        location.fix = testFix(0)
        await engine.logBeerFromIntent()
        let night = try #require(engine.activeNight)
        #expect(night.beerCount == 1)
        #expect(night.entries.first?.latitude == testFix(0).latitude)
    }
}
