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
