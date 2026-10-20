import Foundation
import SwiftData
import os

/// The single writer for places, menus and prices, the way `NightEngine` is for nights.
@MainActor
final class PlaceStore {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.bgergo03.barhop", category: "PlaceStore")

    init(context: ModelContext) {
        self.context = context
    }

    /// The stored place for a Maps candidate, creating it if no stored place matches (SPEC §6).
    func place(for candidate: VenueCandidate) -> Place {
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        if case .existing(let id) = PlaceLinker.match(candidate, among: places.map(\.known)),
           let place = places.first(where: { $0.id == id }) {
            // Matched by name and distance: keep what Maps knows that the place didn't yet.
            if place.mapItemIdentifier == nil { place.mapItemIdentifier = candidate.mapItemIdentifier }
            if place.address == nil { place.address = candidate.address }
            return place
        }
        let place = Place(
            mapItemIdentifier: candidate.mapItemIdentifier,
            name: candidate.name,
            address: candidate.address,
            latitude: candidate.latitude,
            longitude: candidate.longitude
        )
        context.insert(place)
        return place
    }

    func link(_ venue: Venue, to candidate: VenueCandidate) {
        venue.place = place(for: candidate)
        save()
    }

    func unlink(_ venue: Venue) {
        guard venue.place != nil else { return }
        venue.place = nil
        save()
    }

    func setSaved(_ isSaved: Bool, for place: Place) {
        place.isSaved = isSaved
        save()
    }

    /// Records a price you saw. The same drink (category, name ignoring case and accents, size)
    /// gets a new observation; old ones are never edited (SPEC §4).
    @discardableResult
    func addPrice(to place: Place, category: DrinkCategory, name: String, sizeMl: Int?, amount: Decimal, currency: String = "HUF", seenAt: Date = .now) -> MenuItem {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = place.menuItems.first { $0.category == category && $0.sizeMl == sizeMl && PlaceLinker.isSameName($0.name, name) }
            ?? {
                let item = MenuItem(category: category, name: name, sizeMl: sizeMl)
                context.insert(item)
                item.place = place
                return item
            }()
        let price = PriceObservation(amount: amount, currency: currency, seenAt: seenAt)
        context.insert(price)
        price.item = item
        save()
        return item
    }

    /// For mistakes: removes the drink and every price recorded for it.
    func deleteMenuItem(_ item: MenuItem) {
        context.delete(item)
        save()
    }

    /// Drink names used at any place for a category, most used first.
    func nameSuggestions(for category: DrinkCategory) -> [String] {
        let raw = category.rawValue
        let items = (try? context.fetch(FetchDescriptor<MenuItem>(predicate: #Predicate { $0.categoryRaw == raw }))) ?? []
        var counts: [(name: String, count: Int)] = []
        for item in items {
            if let index = counts.firstIndex(where: { PlaceLinker.isSameName($0.name, item.name) }) {
                counts[index].count += 1
            } else {
                counts.append((item.name, 1))
            }
        }
        return counts.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }.map(\.name)
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension Place {
    var known: PlaceLinker.KnownPlace {
        PlaceLinker.KnownPlace(id: id, mapItemIdentifier: mapItemIdentifier, name: name, latitude: latitude, longitude: longitude)
    }
}
