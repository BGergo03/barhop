import Foundation
import Testing
@testable import Barhop

/// Replays the Simulator crawl routes through the trail filter and stop detector, sampling
/// once a second between waypoints the way Xcode's location simulation plays a route.
struct CrawlReplayTests {
    struct Waypoint {
        var latitude: Double
        var longitude: Double
        var time: Date
        var name: String?
    }

    static func loadCrawl(_ file: String = "BudapestCrawl.gpx") throws -> [Waypoint] {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Simulator").appending(path: file)
        let gpx = try String(contentsOf: url, encoding: .utf8)
        let pattern = /<wpt lat="([-\d.]+)" lon="([-\d.]+)"><time>([^<]+)<\/time>(?:<name>([^<]+)<\/name>)?/
        return try gpx.matches(of: pattern).map { match in
            Waypoint(
                latitude: Double(match.1)!,
                longitude: Double(match.2)!,
                time: try Date(String(match.3), strategy: .iso8601),
                name: match.4.map(String.init)
            )
        }
    }

    static func replay(_ waypoints: [Waypoint]) -> [LocationFix] {
        zip(waypoints, waypoints.dropFirst()).flatMap { a, b in
            let seconds = Int(b.time.timeIntervalSince(a.time))
            return (0..<seconds).map { s in
                let f = Double(s) / Double(seconds)
                return LocationFix(
                    timestamp: a.time.addingTimeInterval(Double(s)),
                    latitude: a.latitude + (b.latitude - a.latitude) * f,
                    longitude: a.longitude + (b.longitude - a.longitude) * f,
                    horizontalAccuracy: 10
                )
            }
        }
    }

    @Test(arguments: ["BudapestCrawl.gpx", "BudapestCrawlShort.gpx"])
    func crawlYieldsOneStopPerBar(file: String) throws {
        let waypoints = try Self.loadCrawl(file)
        let bars = waypoints.filter { $0.name != nil }
        #expect(bars.count == 4)

        var filter = TrailFilter()
        var detector = StopDetector()
        var arrivals: [(center: StopDetector.Center, at: Date)] = []
        var departures: [Date] = []
        for fix in Self.replay(waypoints) {
            for point in filter.process(LocationUpdate(fix: fix)) {
                for event in detector.process(point.fix) {
                    switch event {
                    case let .arrived(center, at): arrivals.append((center, at))
                    case let .left(at): departures.append(at)
                    case .moved: break
                    }
                }
            }
        }

        #expect(arrivals.count == 4)
        #expect(departures.count == 3) // still at the last bar when the route ends
        for (bar, arrival) in zip(bars, arrivals) {
            let barFix = LocationFix(timestamp: bar.time, latitude: bar.latitude, longitude: bar.longitude, horizontalAccuracy: 0)
            let centerFix = LocationFix(timestamp: arrival.at, latitude: arrival.center.latitude, longitude: arrival.center.longitude, horizontalAccuracy: 0)
            #expect(barFix.distance(to: centerFix) < 25, "\(bar.name ?? "") center is off")
            // Arrival is the cluster's first point (SPEC §6), which can be a walking point or two
            // before the door, so allow a few minutes.
            #expect(abs(arrival.at.timeIntervalSince(bar.time)) < 180, "\(bar.name ?? "") arrival time is off")
        }
    }
}
