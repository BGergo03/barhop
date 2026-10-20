import Foundation
import SwiftData

/// Linking the stops of nights from before Places existed (SPEC §6, backfill).
extension NightEngine {
    /// MapKit throttles apps that search too often (roughly 50 requests a minute).
    static let backfillPause: Duration = .milliseconds(1500)
    /// Everything Maps returns within the venue radius: in a dense street the stop's own name
    /// can easily be the 10th nearest result.
    static let backfillCandidateLimit = 50

    /// Runs the backfill once per install, in the background. Safe to call on every launch.
    func backfillPlacesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: AppSettings.placesBackfillDoneKey), !isBackfillingPlaces else { return }
        isBackfillingPlaces = true
        Task {
            let finished = await backfillPlaces()
            if finished { UserDefaults.standard.set(true, forKey: AppSettings.placesBackfillDoneKey) }
            isBackfillingPlaces = false
        }
    }

    /// Links each unlinked stop of an ended night to the nearby Maps place with the same name.
    /// Stops named by address stay unlinked, and so do custom names Maps doesn't know.
    /// Returns `false` when it should run again on a later launch: cancelled, or every lookup
    /// came back empty (most likely offline). Stops it already linked are skipped next time.
    @discardableResult
    func backfillPlaces(pause: Duration = backfillPause) async -> Bool {
        let address = NameSource.address.rawValue
        let descriptor = FetchDescriptor<Venue>(
            predicate: #Predicate { $0.place == nil && $0.nameSourceRaw != address },
            sortBy: [SortDescriptor(\.arrivedAt)]
        )
        let venueIDs = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.night?.isActive == false }
            .map(\.id)
        guard !venueIDs.isEmpty else { return true }

        var anyAnswered = false
        for (index, venueID) in venueIDs.enumerated() {
            if index > 0 { try? await Task.sleep(for: pause) }
            if Task.isCancelled { return false }
            // Fetched again after every wait: the stop may have been linked, renamed or deleted meanwhile.
            let byID = FetchDescriptor<Venue>(predicate: #Predicate { $0.id == venueID })
            guard let venue = try? context.fetch(byID).first, venue.place == nil else { continue }
            let candidates = await namer.candidates(latitude: venue.latitude, longitude: venue.longitude, limit: Self.backfillCandidateLimit)
            anyAnswered = anyAnswered || !candidates.isEmpty
            guard venue.place == nil, let match = candidates.first(where: { PlaceLinker.isSameName($0.name, venue.name) }) else { continue }
            places.link(venue, to: match)
        }
        return anyAnswered
    }
}
