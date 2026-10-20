import Foundation
import SwiftData

enum EndReason: String, Codable {
    case manual
    case autoClosed
}

@Model
final class Night {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    /// `nil` while the night is active.
    var endedAt: Date?
    var endReasonRaw: String?
    var showMapOnShare: Bool = true
    @Relationship(deleteRule: .cascade, inverse: \Entry.night) var entries: [Entry] = []
    @Relationship(deleteRule: .cascade, inverse: \TrailPoint.night) var trailPoints: [TrailPoint] = []
    @Relationship(deleteRule: .cascade, inverse: \Venue.night) var venues: [Venue] = []
    /// Last entry, or start if none. Drives the "Still out?" auto-close.
    var lastActivityAt: Date

    init(id: UUID = UUID(), startedAt: Date = .now) {
        self.id = id
        self.startedAt = startedAt
        self.lastActivityAt = startedAt
    }

    var endReason: EndReason? {
        get { endReasonRaw.flatMap(EndReason.init(rawValue:)) }
        set { endReasonRaw = newValue?.rawValue }
    }

    var isActive: Bool { endedAt == nil }
}
