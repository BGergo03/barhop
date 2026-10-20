import Foundation
import SwiftData

enum DrinkCategory: String, Codable, CaseIterable {
    case beer
    case wine
    case shot
    case cocktail
    case soft
}

/// A drink a place serves, identified by category + name + size (SPEC §3).
@Model
final class MenuItem {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var name: String
    var sizeMl: Int?
    @Relationship(deleteRule: .cascade, inverse: \PriceObservation.item) var prices: [PriceObservation] = []
    var place: Place?

    init(id: UUID = UUID(), category: DrinkCategory, name: String, sizeMl: Int?) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.name = name
        self.sizeMl = sizeMl
    }

    var category: DrinkCategory {
        get { DrinkCategory(rawValue: categoryRaw) ?? .beer }
        set { categoryRaw = newValue.rawValue }
    }
}
