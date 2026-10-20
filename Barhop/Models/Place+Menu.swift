import Foundation

extension MenuItem {
    /// The newest observation by when it was seen, not when it was entered.
    var latestPrice: PriceObservation? { prices.max { $0.seenAt < $1.seenAt } }
}

extension Place {
    /// The 0.5 L beer size Map and Search compare places by (SPEC §7).
    static let referenceBeerMl = 500

    /// The newest price seen for any 0.5 L beer here.
    var latestBeerPrice: PriceObservation? {
        menuItems
            .filter { $0.category == .beer && $0.sizeMl == Self.referenceBeerMl }
            .compactMap(\.latestPrice)
            .max { $0.seenAt < $1.seenAt }
    }

    /// Menu items grouped by category in a fixed order, each group sorted by name.
    var menuByCategory: [(category: DrinkCategory, items: [MenuItem])] {
        DrinkCategory.allCases.compactMap { category in
            let items = menuItems.filter { $0.category == category }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending || ($0.name == $1.name && ($0.sizeMl ?? 0) < ($1.sizeMl ?? 0)) }
            return items.isEmpty ? nil : (category, items)
        }
    }
}
