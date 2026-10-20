import Foundation
import SwiftData
import Testing
@testable import Barhop

@MainActor
struct PlaceTests {
    let container = TestSupport.makeContainer()
    let location = FakeLocationProvider()
    let namer = FakeVenueNamer()
    let liveActivity = FakeLiveActivity()
    let reminders = FakeReminders()

    func makeEngine() -> NightEngine {
        NightEngine(context: container.mainContext, location: location, namer: namer, liveActivity: liveActivity, reminders: reminders, autoClose: { .neverInTests })
    }

    func candidate(_ name: String, identifier: String? = nil) -> VenueCandidate {
        VenueCandidate(name: name, latitude: 47.5, longitude: 19.06, distance: 10, mapItemIdentifier: identifier, address: "Kazinczy utca 14")
    }

    func storedPlaces() throws -> [Place] {
        try container.mainContext.fetch(FetchDescriptor<Place>())
    }

    /// One beer at the origin on a night that then ends, with the namer as currently set up.
    @discardableResult
    func nightWithBeer(_ engine: NightEngine, at seconds: TimeInterval) async throws -> Venue {
        location.fix = testFix(seconds)
        let entry = engine.logBeer(at: testFix(seconds).timestamp)
        await TestSupport.settle()
        let night = try #require(entry.night)
        engine.endNight(night, at: testFix(seconds + 3600).timestamp)
        return try #require(entry.venue)
    }

    /// A stop from before Places existed: an ended night whose venue has no place.
    func legacyStop(named name: String, source: NameSource = .auto) -> Venue {
        let context = container.mainContext
        let night = Night(startedAt: testFix(0).timestamp)
        night.endedAt = testFix(3600).timestamp
        let venue = Venue(name: name, nameSource: source, latitude: 47.5, longitude: 19.06, arrivedAt: testFix(0).timestamp)
        context.insert(night)
        context.insert(venue)
        venue.night = night
        try? context.save()
        return venue
    }

    @Test func autoNamedStopLinksToNewPlace() async throws {
        let engine = makeEngine()
        namer.candidates = [candidate("Szimpla Kert", identifier: "I1")]
        let venue = try await nightWithBeer(engine, at: 0)

        let place = try #require(venue.place)
        #expect(place.name == "Szimpla Kert")
        #expect(place.mapItemIdentifier == "I1")
        #expect(place.address == "Kazinczy utca 14")
        #expect(try storedPlaces().count == 1)
    }

    @Test func sameBarOnTwoNightsIsOnePlaceWithTwoVisits() async throws {
        let engine = makeEngine()
        namer.candidates = [candidate("Szimpla Kert", identifier: "I1")]
        let first = try await nightWithBeer(engine, at: 0)
        let second = try await nightWithBeer(engine, at: 86_400)

        #expect(first.place?.id == second.place?.id)
        #expect(try storedPlaces().count == 1)
        #expect(first.place?.visits.count == 2)
    }

    @Test func addressNamedStopStaysUnlinked() async throws {
        let engine = makeEngine()
        namer.address = "Kazinczy utca 14"
        let venue = try await nightWithBeer(engine, at: 0)

        #expect(venue.nameSource == .address)
        #expect(venue.place == nil)
        #expect(try storedPlaces().isEmpty)
    }

    @Test func pickingCandidateLinksStop() async throws {
        let engine = makeEngine()
        namer.address = "Kazinczy utca 14"
        let venue = try await nightWithBeer(engine, at: 0)
        engine.renameVenue(venue, to: candidate("Instant", identifier: "I2"))

        #expect(venue.name == "Instant")
        #expect(venue.nameSource == .user)
        #expect(venue.place?.mapItemIdentifier == "I2")
    }

    @Test func customNameRenamesOnlyTheStop() async throws {
        let engine = makeEngine()
        namer.candidates = [candidate("Szimpla Kert", identifier: "I1")]
        let venue = try await nightWithBeer(engine, at: 0)
        engine.renameVenue(venue, to: "Our spot")

        #expect(venue.name == "Our spot")
        #expect(venue.place?.name == "Szimpla Kert")
    }

    @Test func deletingNightKeepsItsPlaces() async throws {
        let engine = makeEngine()
        namer.candidates = [candidate("Szimpla Kert", identifier: "I1")]
        let venue = try await nightWithBeer(engine, at: 0)
        let night = try #require(venue.night)
        engine.deleteNight(night)

        let place = try #require(try storedPlaces().first)
        #expect(place.stops.isEmpty)
    }

    @Test func backfillLinksPastStopsByName() async throws {
        let engine = makeEngine()
        let named = legacyStop(named: "Szimpla Kert")
        let picked = legacyStop(named: "Instant", source: .user)
        namer.candidates = [candidate("Instant", identifier: "I2"), candidate("Szimpla Kert", identifier: "I1")]

        let finished = await engine.backfillPlaces(pause: .zero)

        #expect(finished)
        #expect(named.place?.mapItemIdentifier == "I1")
        #expect(picked.place?.mapItemIdentifier == "I2")
    }

    @Test func backfillSkipsAddressesCustomNamesAndTheActiveNight() async throws {
        let engine = makeEngine()
        let address = legacyStop(named: "Kazinczy utca 14", source: .address)
        let custom = legacyStop(named: "Our spot", source: .user)
        namer.candidates = [candidate("Kazinczy utca 14"), candidate("Szimpla Kert", identifier: "I1")]
        location.fix = testFix(0)
        let entry = engine.logBeer(at: testFix(0).timestamp)
        await TestSupport.settle()
        let live = try #require(entry.venue)
        engine.places.unlink(live)

        await engine.backfillPlaces(pause: .zero)

        #expect(address.place == nil)
        #expect(custom.place == nil)
        #expect(live.place == nil)
    }

    @Test func backfillRunsAgainWhenEveryLookupCameBackEmpty() async throws {
        let engine = makeEngine()
        let stop = legacyStop(named: "Szimpla Kert")

        #expect(await engine.backfillPlaces(pause: .zero) == false)
        #expect(stop.place == nil)
    }
}
