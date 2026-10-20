import CoreGraphics
import CoreLocation
import Foundation

/// Everything the share card and sticker show (SPEC §9), copied out of the night as plain
/// values so it can be rendered later, off the SwiftData context.
struct ShareContent: Sendable, Equatable {
    struct Coordinate: Sendable, Equatable {
        var latitude: Double
        var longitude: Double
    }

    /// Venue names listed on the card before collapsing the rest into "+N more".
    static let maxListedVenues = 6

    var startedAt: Date
    var title: String
    var duration: TimeInterval
    var beers: Int
    var liters: Double
    /// `nil` when the night has no trail, so the renders leave distance out instead of showing 0.
    var distance: CLLocationDistance?
    /// Ordered by arrival.
    var venueNames: [String]
    /// Coordinates per trail segment.
    var segments: [[Coordinate]]
    var venues: [Coordinate]
    var showsMap: Bool

    /// Whether there is a trail or a venue to draw.
    var hasRoute: Bool { segments.contains { !$0.isEmpty } || !venues.isEmpty }

    /// The map (card) or trail (sticker) is drawn only when there is one and the toggle is on.
    var drawsMap: Bool { showsMap && hasRoute }

    /// Venue names to list, and how many more are left out.
    var listedVenues: (names: [String], more: Int) {
        (Array(venueNames.prefix(Self.maxListedVenues)), max(0, venueNames.count - Self.maxListedVenues))
    }

    /// `Barhop-YYYY-MM-DD.png`, dated by the night's start in the given time zone.
    static func fileName(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "Barhop-%04d-%02d-%02d.png", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }
}

extension ShareContent {
    @MainActor
    init(night: Night, now: Date = .now) {
        let stats = ReportStats(night: night, now: now)
        let segments = TrailGeometry.segmentFixes(night.trailPoints).map { segment in
            segment.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }
        self.init(
            startedAt: night.startedAt,
            title: night.title,
            duration: stats.duration,
            beers: stats.beers,
            liters: stats.liters,
            distance: night.trailPoints.isEmpty ? nil : stats.distance,
            venueNames: stats.venues.map(\.name),
            segments: segments,
            venues: night.venues.sorted { $0.arrivedAt < $1.arrivedAt }.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) },
            showsMap: night.showMapOnShare
        )
    }
}

/// Projects the trail into a fixed box for the sticker, north up, keeping its proportions.
struct TrailProjection {
    let size: CGSize
    private let center: ShareContent.Coordinate
    /// Points per degree of latitude; longitude is scaled by cos(latitude) on top.
    private let scale: Double
    private let longitudeFactor: Double

    /// - Parameters:
    ///   - coordinates: everything that must fit (trail and venues).
    ///   - size: the box; the trail is centered in it.
    ///   - inset: margin kept free on every side, e.g. for line width and pins.
    init(fitting coordinates: [ShareContent.Coordinate], in size: CGSize, inset: CGFloat) {
        self.size = size
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? 0, maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0, maxLon = longitudes.max() ?? 0
        center = .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        longitudeFactor = cos(center.latitude * .pi / 180)
        let spanY = maxLat - minLat
        let spanX = (maxLon - minLon) * longitudeFactor
        let available = (width: max(1, Double(size.width - 2 * inset)), height: max(1, Double(size.height - 2 * inset)))
        let candidates = [spanX > 0 ? available.width / spanX : nil, spanY > 0 ? available.height / spanY : nil].compactMap { $0 }
        // A single point (or nothing) just sits in the middle.
        scale = candidates.min() ?? 0
    }

    func point(for coordinate: ShareContent.Coordinate) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (coordinate.longitude - center.longitude) * longitudeFactor * scale,
            y: size.height / 2 - (coordinate.latitude - center.latitude) * scale
        )
    }
}
