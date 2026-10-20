import Foundation

extension Night {
    /// Titled by the start date even when the night crosses midnight ("Sat 24 Oct").
    var title: String { Self.title(for: startedAt) }

    static func title(for date: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle(locale: locale, timeZone: timeZone)
        style = style.weekday(.abbreviated).day().month(.abbreviated)
        return date.formatted(style)
    }

    var sortedEntries: [Entry] { entries.sorted { $0.timestamp > $1.timestamp } }

    var beerCount: Int { entries.filter { $0.drink?.drinkType == DrinkPayload.beer.drinkType }.count }

    var liters: Double { Double(entries.compactMap(\.drink?.volumeMl).reduce(0, +)) / 1000 }

    func duration(now: Date = .now) -> TimeInterval { (endedAt ?? now).timeIntervalSince(startedAt) }

    var currentVenue: Venue? {
        venues.filter { $0.leftAt == nil }.max { $0.arrivedAt < $1.arrivedAt }
    }

    /// Valid range for an entry's timestamp.
    func entryTimeRange(now: Date = .now) -> ClosedRange<Date> { startedAt...max(startedAt, endedAt ?? now) }
}

extension TimeInterval {
    var durationText: String {
        Duration.seconds(self).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
