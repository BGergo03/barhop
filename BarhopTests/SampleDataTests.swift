import Foundation
import SwiftData
import Testing
@testable import Barhop

@MainActor
struct SampleDataTests {
    let container = TestSupport.makeContainer()

    func makeEngine() -> NightEngine {
        NightEngine(context: container.mainContext, location: FakeLocationProvider(), namer: FakeVenueNamer(), liveActivity: FakeLiveActivity(), reminders: FakeReminders(), autoClose: { .neverInTests })
    }

    @Test func addsEndedNightsLinkedToPlacesAndRemovesOnlyThem() throws {
        let engine = makeEngine()
        let context = container.mainContext
        // The test host shares the app's defaults, which may remember a real seeding.
        let defaults = UserDefaults.standard
        let seeded = defaults.object(forKey: AppSettings.sampleDataIDsKey)
        defaults.removeObject(forKey: AppSettings.sampleDataIDsKey)
        defer { defaults.set(seeded, forKey: AppSettings.sampleDataIDsKey) }
        let real = engine.startNight(at: testFix(0).timestamp)
        engine.endNight(real, at: testFix(3600).timestamp)

        engine.addSampleData()

        let nights = try context.fetch(FetchDescriptor<Night>())
        let places = try context.fetch(FetchDescriptor<Place>())
        #expect(nights.count == 6)
        #expect(nights.allSatisfy { !$0.isActive })
        #expect(places.count == 8)
        #expect(places.filter(\.isSaved).count == 2)
        #expect(nights.filter { $0.id != real.id }.allSatisfy { night in night.venues.allSatisfy { $0.place != nil } && night.beerCount > 0 })

        engine.removeSampleData()

        #expect(try context.fetch(FetchDescriptor<Night>()).map(\.id) == [real.id])
        #expect(try context.fetch(FetchDescriptor<Place>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PriceObservation>()).isEmpty)
        #expect(!engine.hasSampleData)
    }
}
