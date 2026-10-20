import Foundation
import SwiftData

enum NameSource: String, Codable {
    case auto
    case user
    case address
}

@Model
final class Venue {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameSourceRaw: String
    var latitude: Double
    var longitude: Double
    var arrivedAt: Date
    var leftAt: Date?
    var night: Night?
    @Relationship(deleteRule: .nullify, inverse: \Entry.venue) var entries: [Entry] = []

    init(
        id: UUID = UUID(),
        name: String,
        nameSource: NameSource,
        latitude: Double,
        longitude: Double,
        arrivedAt: Date
    ) {
        self.id = id
        self.name = name
        self.nameSourceRaw = nameSource.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.arrivedAt = arrivedAt
    }

    var nameSource: NameSource {
        get { NameSource(rawValue: nameSourceRaw) ?? .auto }
        set { nameSourceRaw = newValue.rawValue }
    }
}
