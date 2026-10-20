import CoreLocation

enum TrailGeometry {
    /// Fixes per segment, in time order.
    static func segmentFixes(_ points: [TrailPoint]) -> [[LocationFix]] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        var result: [[LocationFix]] = []
        var currentSegment: Int?
        for point in sorted {
            if point.segment == currentSegment {
                result[result.count - 1].append(point.fix)
            } else {
                result.append([point.fix])
                currentSegment = point.segment
            }
        }
        return result
    }

    /// Coordinates per segment, in time order.
    static func segments(_ points: [TrailPoint]) -> [[CLLocationCoordinate2D]] {
        segmentFixes(points).map { $0.map(\.coordinate) }
    }

    /// Straight connectors from the end of each segment to the start of the next, drawn dashed.
    static func gaps<Point>(between segments: [[Point]]) -> [[Point]] {
        zip(segments, segments.dropFirst()).compactMap { previous, next in
            guard let end = previous.last, let start = next.first else { return nil }
            return [end, start]
        }
    }

    /// Distance walked in meters, excluding the gaps between segments.
    static func walkedDistance(_ points: [TrailPoint]) -> CLLocationDistance {
        walkedDistance(segments: segmentFixes(points))
    }

    /// Time at a venue, for leaving GPS drift out of the walked distance.
    struct Stay {
        var during: ClosedRange<Date>
        var latitude: Double
        var longitude: Double
    }

    /// Distance walked in meters, excluding the gaps between segments and drift during stays:
    /// a fix taken during a stay and within `StopDetector.radius` of the venue counts as being at
    /// the venue, so sitting still adds nothing while the walk in and out is still measured.
    static func walkedDistance(segments: [[LocationFix]], stays: [Stay] = []) -> CLLocationDistance {
        segments.reduce(0) { total, segment in
            let fixes = segment.map { snapped($0, to: stays) }
            return total + zip(fixes, fixes.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
        }
    }

    private static func snapped(_ fix: LocationFix, to stays: [Stay]) -> LocationFix {
        for stay in stays where stay.during.contains(fix.timestamp) {
            var center = fix
            center.latitude = stay.latitude
            center.longitude = stay.longitude
            if fix.distance(to: center) <= StopDetector.radius { return center }
        }
        return fix
    }
}
