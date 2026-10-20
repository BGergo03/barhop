import Foundation
import SwiftData

enum EntryKind: String, Codable {
    case drink
    // future: cigarette, pouch, photo
}

struct DrinkPayload: Codable, Equatable {
    var drinkType: String
    var volumeMl: Int

    static let beer = DrinkPayload(drinkType: "beer", volumeMl: 500)
}

@Model
final class Entry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    /// When the entry was logged. Unlike `timestamp` it is never edited,
    /// so the 60 s undo window (SPEC §8) can't be reopened by a time edit.
    var createdAt: Date
    var kindRaw: String
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    /// JSON-encoded, shape depends on `kind`.
    var payload: Data
    var venue: Venue?
    var night: Night?

    init(id: UUID = UUID(), timestamp: Date, kind: EntryKind, payload: Data) {
        self.id = id
        self.timestamp = timestamp
        self.createdAt = timestamp
        self.kindRaw = kind.rawValue
        self.payload = payload
    }

    convenience init(drink: DrinkPayload, at timestamp: Date) {
        // Encoding a struct of a String and an Int cannot fail.
        let data = (try? JSONEncoder().encode(drink)) ?? Data()
        self.init(timestamp: timestamp, kind: .drink, payload: data)
    }

    var kind: EntryKind? { EntryKind(rawValue: kindRaw) }

    var drink: DrinkPayload? {
        guard kind == .drink else { return nil }
        return try? JSONDecoder().decode(DrinkPayload.self, from: payload)
    }
}
