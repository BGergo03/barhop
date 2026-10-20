import Foundation
import SwiftData

@Model
final class TrailPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    /// Increments after a tracking gap.
    var segment: Int
    var night: Night?

    init(timestamp: Date, latitude: Double, longitude: Double, horizontalAccuracy: Double, segment: Int) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.segment = segment
    }
}
