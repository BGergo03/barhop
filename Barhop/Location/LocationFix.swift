import CoreLocation
import Foundation

/// A location reading, decoupled from Core Location types so the trail logic stays pure.
struct LocationFix: Equatable, Sendable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    func distance(to other: LocationFix) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

extension LocationFix {
    init(_ location: CLLocation) {
        self.init(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }
}

struct LocationUpdate: Sendable {
    var fix: LocationFix?
    /// Core Location pauses updates after reporting that the device is stationary.
    var isStationary: Bool = false
}
