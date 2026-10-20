import Foundation
import SwiftData

/// A bar as a lasting thing, across nights (SPEC §3). A night's stops (`Venue`) link to it;
/// those stops are its visits.
@Model
final class Place {
    @Attribute(.unique) var id: UUID
    /// `MKMapItem.identifier`, when Apple Maps gave one.
    var mapItemIdentifier: String?
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    /// The "want to go" bookmark.
    var isSaved: Bool = false
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MenuItem.place) var menuItems: [MenuItem] = []
    @Relationship(deleteRule: .nullify, inverse: \Venue.place) var stops: [Venue] = []

    init(
        id: UUID = UUID(),
        mapItemIdentifier: String?,
        name: String,
        address: String?,
        latitude: Double,
        longitude: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.mapItemIdentifier = mapItemIdentifier
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    /// Stops of ended nights, newest first. Derived, never stored (SPEC §4).
    var visits: [Venue] {
        stops.filter { $0.night?.isActive == false }.sorted { $0.arrivedAt > $1.arrivedAt }
    }

    var lastVisitedAt: Date? { stops.map(\.arrivedAt).max() }
}
