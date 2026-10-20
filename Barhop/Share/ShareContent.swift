import CoreGraphics
import CoreLocation
import Foundation

/// Everything the share card and sticker show (SPEC §9), copied out of the night as plain
/// values so it can be rendered later, off the SwiftData context.
struct ShareContent: Sendable, Equatable {
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
    var segments: [[MapPoint]]
    var venues: [MapPoint]
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
        self.init(
            startedAt: night.startedAt,
            title: night.title,
            duration: stats.duration,
            beers: stats.beers,
            liters: stats.liters,
            distance: night.trailPoints.isEmpty ? nil : stats.distance,
            venueNames: stats.venues.map(\.name),
            segments: TrailGeometry.segmentPoints(night.trailPoints),
            venues: night.venues.sorted { $0.arrivedAt < $1.arrivedAt }.map(\.mapPoint),
            showsMap: night.showMapOnShare
        )
    }
}
