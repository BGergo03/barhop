import Foundation
import SwiftData
import Testing
@testable import Barhop

@MainActor
struct NightEngineTests {
    let container = ModelContainerFactory.make(inMemory: true)
    var engine: NightEngine { NightEngine(context: container.mainContext) }

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
}
