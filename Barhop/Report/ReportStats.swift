import CoreLocation
import Foundation

/// Everything the report shows about a night (SPEC §7). Pure: built from plain values so it can
/// be checked against a hand calculation; `init(night:)` adapts the SwiftData models.
struct ReportStats: Equatable {
    struct Drink: Equatable {
        var timestamp: Date
        var payload: DrinkPayload
    }

    struct Stay: Equatable {
        var id: UUID
        var name: String
        var arrivedAt: Date
        /// `nil` while still there; counts until the end of the night.
        var leftAt: Date?
    }

    struct VenueTime: Equatable, Identifiable {
        var id: UUID
        var name: String
        var arrivedAt: Date
        var timeSpent: TimeInterval
    }

    /// Pace needs a meaningful duration; shorter nights show "—".
    static let minimumPaceDuration: TimeInterval = 60

    var duration: TimeInterval
    var beers: Int
    var liters: Double
    /// Beers per hour, `nil` for nights shorter than `minimumPaceDuration`.
    var pace: Double?
    /// Longest time between consecutive beers, `nil` with fewer than two.
    var longestGap: TimeInterval?
    /// Meters walked within segments; tracking gaps don't count.
    var distance: CLLocationDistance
    /// Ordered by arrival.
    var venues: [VenueTime]

    init(
        startedAt: Date,
        endedAt: Date,
        drinks: [Drink],
        segments: [[CLLocationCoordinate2D]],
        stays: [Stay]
    ) {
        duration = max(0, endedAt.timeIntervalSince(startedAt))

        let beerTimes = drinks
            .filter { $0.payload.drinkType == DrinkPayload.beer.drinkType }
            .map(\.timestamp)
            .sorted()
        beers = beerTimes.count
        liters = Double(drinks.map(\.payload.volumeMl).reduce(0, +)) / 1000
        pace = duration < Self.minimumPaceDuration ? nil : Double(beers) / (duration / 3600)
        longestGap = zip(beerTimes, beerTimes.dropFirst()).map { $1.timeIntervalSince($0) }.max()

        distance = TrailGeometry.walkedDistance(segments: segments)

        venues = stays
            .sorted { $0.arrivedAt < $1.arrivedAt }
            .map { stay in
                VenueTime(
                    id: stay.id,
                    name: stay.name,
                    arrivedAt: stay.arrivedAt,
                    timeSpent: max(0, (stay.leftAt ?? endedAt).timeIntervalSince(stay.arrivedAt))
                )
            }
    }
}

extension ReportStats {
    /// An active night is measured up to `now`.
    init(night: Night, now: Date = .now) {
        self.init(
            startedAt: night.startedAt,
            endedAt: night.endedAt ?? now,
            drinks: night.entries.compactMap { entry in
                entry.drink.map { Drink(timestamp: entry.timestamp, payload: $0) }
            },
            segments: TrailGeometry.segments(night.trailPoints),
            stays: night.venues.map {
                Stay(id: $0.id, name: $0.name, arrivedAt: $0.arrivedAt, leftAt: $0.leftAt)
            }
        )
    }
}
