import Foundation
import SwiftData

/// One price seen for a menu item on a given date. Append-only: a newer price is a new
/// observation, never an edit (SPEC §4).
@Model
final class PriceObservation {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    /// ISO 4217 code; the UI only offers "HUF" for now.
    var currency: String
    var seenAt: Date
    var item: MenuItem?

    init(id: UUID = UUID(), amount: Decimal, currency: String, seenAt: Date = .now) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.seenAt = seenAt
    }
}
