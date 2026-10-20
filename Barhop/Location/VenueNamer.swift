import CoreLocation
import MapKit

struct VenueCandidate: Identifiable, Hashable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var distance: Double
    /// `MKMapItem.identifier`, which links the stop to a lasting place (SPEC §6).
    var mapItemIdentifier: String? = nil
    var address: String? = nil

    var id: String { "\(name)|\(latitude)|\(longitude)" }
}

@MainActor
protocol VenueNaming {
    /// Nightlife-ish points of interest around a coordinate, nearest first.
    func candidates(latitude: Double, longitude: Double, limit: Int) async -> [VenueCandidate]
    /// Street address fallback ("Kazinczy utca 14").
    func address(latitude: Double, longitude: Double) async -> String?
}

@MainActor
final class VenueNamer: VenueNaming {
    private static let searchRadius: CLLocationDistance = 75
    private static let categories: [MKPointOfInterestCategory] = [.nightlife, .brewery, .winery, .restaurant, .cafe]

    func candidates(latitude: Double, longitude: Double, limit: Int) async -> [VenueCandidate] {
        let center = CLLocation(latitude: latitude, longitude: longitude)
        // MapKit throws (not returns an error) for an invalid coordinate, and the backfill
        // feeds it stored data on every launch until it finishes.
        guard CLLocationCoordinate2DIsValid(center.coordinate) else { return [] }
        let request = MKLocalPointsOfInterestRequest(center: center.coordinate, radius: Self.searchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.categories)
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems
            .compactMap { item -> VenueCandidate? in
                guard let name = item.name else { return nil }
                return VenueCandidate(
                    name: name,
                    latitude: item.location.coordinate.latitude,
                    longitude: item.location.coordinate.longitude,
                    distance: item.location.distance(from: center),
                    mapItemIdentifier: item.identifier?.rawValue,
                    address: item.address?.shortAddress
                )
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }

    func address(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        // The short address reads "street number, city"; the street part alone is enough here.
        if let street = item.address?.shortAddress?.split(separator: ",").first {
            return street.trimmingCharacters(in: .whitespaces)
        }
        return item.name
    }
}
