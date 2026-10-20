import Foundation
import SwiftData
import Testing
@testable import Barhop

@MainActor
struct MenuTests {
    let container = TestSupport.makeContainer()

    func makeStore() -> PlaceStore { PlaceStore(context: container.mainContext) }

    func makePlace(_ store: PlaceStore, name: String = "Szimpla Kert") -> Place {
        store.place(for: VenueCandidate(name: name, latitude: 47.5, longitude: 19.06, distance: 0, mapItemIdentifier: name))
    }

    func day(_ days: Double) -> Date { Date(timeIntervalSince1970: 1_000_000 + days * 86_400) }

    @Test func newPriceForSameBeerAppendsToOneItem() throws {
        let store = makeStore()
        let place = makePlace(store)
        store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1200, seenAt: day(0))
        store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1300, seenAt: day(1))

        let item = try #require(place.menuItems.first)
        #expect(place.menuItems.count == 1)
        #expect(item.prices.count == 2)
        #expect(item.latestPrice?.amount == 1300)
        #expect(item.latestPrice?.currency == "HUF")
    }

    @Test func sameDrinkIgnoresCaseAccentsAndSpaces() {
        let store = makeStore()
        let place = makePlace(store)
        store.addPrice(to: place, category: .shot, name: "Pálinka", sizeMl: 40, amount: 1490)
        let item = store.addPrice(to: place, category: .shot, name: "  palinka ", sizeMl: 40, amount: 1590)

        #expect(place.menuItems.count == 1)
        #expect(item.name == "Pálinka")
    }

    @Test func otherSizeOrCategoryIsAnotherItem() {
        let store = makeStore()
        let place = makePlace(store)
        store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1300)
        store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 330, amount: 990)
        store.addPrice(to: place, category: .soft, name: "Dreher", sizeMl: 500, amount: 900)

        #expect(place.menuItems.count == 3)
    }

    @Test func latestPriceIsNewestSeenNotNewestEntered() {
        let store = makeStore()
        let place = makePlace(store)
        // Entering an old receipt after a newer price.
        store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1690, seenAt: day(10))
        let item = store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1490, seenAt: day(2))

        #expect(item.latestPrice?.amount == 1690)
    }

    @Test func latestBeerPriceIsNewestHalfLiterBeer() {
        let store = makeStore()
        let place = makePlace(store)
        store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1300, seenAt: day(1))
        store.addPrice(to: place, category: .beer, name: "Soproni", sizeMl: 500, amount: 1250, seenAt: day(3))
        store.addPrice(to: place, category: .beer, name: "IPA", sizeMl: 400, amount: 1900, seenAt: day(5))

        #expect(place.latestBeerPrice?.amount == 1250)
    }

    @Test func suggestionsComeFromEveryPlaceMostUsedFirst() {
        let store = makeStore()
        let first = makePlace(store)
        let second = makePlace(store, name: "Instant")
        store.addPrice(to: first, category: .beer, name: "Soproni", sizeMl: 500, amount: 1200)
        store.addPrice(to: first, category: .beer, name: "Dreher", sizeMl: 500, amount: 1300)
        store.addPrice(to: second, category: .beer, name: "dreher", sizeMl: 500, amount: 1400)
        store.addPrice(to: second, category: .wine, name: "Fröccs", sizeMl: 300, amount: 1100)

        #expect(store.nameSuggestions(for: .beer) == ["Dreher", "Soproni"])
    }

    @Test func deletingDrinkRemovesItsPrices() throws {
        let store = makeStore()
        let place = makePlace(store)
        let item = store.addPrice(to: place, category: .beer, name: "Dreher", sizeMl: 500, amount: 1300)
        store.deleteMenuItem(item)

        #expect(place.menuItems.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<PriceObservation>()).isEmpty)
    }

    @Test func savingIsAFlagOnThePlace() {
        let store = makeStore()
        let place = makePlace(store)
        store.setSaved(true, for: place)
        #expect(place.isSaved)
    }
}
