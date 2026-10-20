import CoreLocation
import MapKit

struct VenueCandidate: Identifiable, Hashable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var distance: Double

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
        let request = MKLocalPointsOfInterestRequest(center: center.coordinate, radius: Self.searchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.categories)
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems
            .compactMap { item -> VenueCandidate? in
                guard let name = item.name, let location = item.placemark.location else { return nil }
                return VenueCandidate(
                    name: name,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    distance: location.distance(from: center)
                )
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }

    func address(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        if let street = placemark.thoroughfare {
            return [street, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        }
        return placemark.name
    }
}
