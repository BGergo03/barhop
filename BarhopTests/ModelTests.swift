import Foundation
import Testing
@testable import Barhop

struct ModelTests {
    @Test func drinkPayloadRoundTrips() {
        let entry = Entry(drink: .beer, at: .now)
        #expect(entry.kind == .drink)
        #expect(entry.drink == .beer)
    }

    @Test func unknownKindDecodesToNil() {
        let entry = Entry(timestamp: .now, kind: .drink, payload: Data())
        entry.kindRaw = "cigarette"
        #expect(entry.kind == nil)
        #expect(entry.drink == nil)
    }

    @Test func nightTitleUsesStartDateAcrossMidnight() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 21)))
        let night = Night(startedAt: start)
        night.endedAt = start.addingTimeInterval(6 * 3600) // 03:00 on Sunday

        let title = Night.title(for: night.startedAt, locale: Locale(identifier: "en_GB"), timeZone: timeZone)
        #expect(title == "Sat 24 Oct")
    }
}
