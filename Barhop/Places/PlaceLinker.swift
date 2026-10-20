import Foundation

/// Decides which lasting place a named stop belongs to (SPEC §6). Pure, so it can be tested
/// without SwiftData or MapKit.
enum PlaceLinker {
    /// The parts of a stored place the decision looks at.
    struct KnownPlace: Equatable {
        var id: UUID
        var mapItemIdentifier: String?
        var name: String
        var latitude: Double
        var longitude: Double
    }

    enum Match: Equatable {
        case existing(UUID)
        case create
    }

    /// Same name within this distance counts as the same place when identifiers can't decide.
    static let sameNameRadius: Double = StopDetector.radius

    static func match(_ candidate: VenueCandidate, among places: [KnownPlace]) -> Match {
        if let identifier = candidate.mapItemIdentifier,
           let place = places.first(where: { $0.mapItemIdentifier == identifier }) {
            return .existing(place.id)
        }
        let nearby = places
            // Two different Apple Maps identifiers are two different places, whatever their names.
            .filter { $0.mapItemIdentifier == nil || candidate.mapItemIdentifier == nil }
            .filter { isSameName($0.name, candidate.name) }
            .map { (place: $0, distance: distance(from: $0, to: candidate)) }
            .filter { $0.distance <= sameNameRadius }
            .min { $0.distance < $1.distance }
        if let nearby { return .existing(nearby.place.id) }
        return .create
    }

    static func isSameName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(rhs.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func distance(from place: KnownPlace, to candidate: VenueCandidate) -> Double {
        let placeFix = LocationFix(timestamp: .distantPast, latitude: place.latitude, longitude: place.longitude, horizontalAccuracy: 0)
        let candidateFix = LocationFix(timestamp: .distantPast, latitude: candidate.latitude, longitude: candidate.longitude, horizontalAccuracy: 0)
        return placeFix.distance(to: candidateFix)
    }
}
