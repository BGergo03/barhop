import ActivityKit
import Foundation

struct NightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var beerCount: Int
        var currentVenueName: String?
        var lastEntryID: UUID?
        var undoUntil: Date?
    }

    var nightID: UUID
    var startedAt: Date
}
