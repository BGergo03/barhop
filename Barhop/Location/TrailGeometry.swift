import CoreLocation

enum TrailGeometry {
    /// Coordinates per segment, in time order.
    static func segments(_ points: [TrailPoint]) -> [[CLLocationCoordinate2D]] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        var result: [[CLLocationCoordinate2D]] = []
        var currentSegment: Int?
        for point in sorted {
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            if point.segment == currentSegment {
                result[result.count - 1].append(coordinate)
            } else {
                result.append([coordinate])
                currentSegment = point.segment
            }
        }
        return result
    }

    /// Straight connectors from the end of each segment to the start of the next, drawn dashed.
    static func gaps(between segments: [[CLLocationCoordinate2D]]) -> [[CLLocationCoordinate2D]] {
        zip(segments, segments.dropFirst()).compactMap { previous, next in
            guard let end = previous.last, let start = next.first else { return nil }
            return [end, start]
        }
    }

    /// Distance walked in meters, excluding the gaps between segments.
    static func walkedDistance(_ points: [TrailPoint]) -> CLLocationDistance {
        walkedDistance(segments: segments(points))
    }

    static func walkedDistance(segments: [[CLLocationCoordinate2D]]) -> CLLocationDistance {
        segments.reduce(0) { total, segment in
            total + zip(segment, segment.dropFirst()).reduce(0) { sum, pair in
                sum + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                    .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
            }
        }
    }
}
