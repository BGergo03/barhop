import Foundation

extension DrinkCategory {
    /// One drink of the category, for the picker ("Shot").
    var title: LocalizedStringResource {
        switch self {
        case .beer: "Beer"
        case .wine: "Wine"
        case .shot: "Shot"
        case .cocktail: "Cocktail"
        case .soft: "Soft drink"
        }
    }

    /// The menu group ("Shots").
    var sectionTitle: LocalizedStringResource {
        switch self {
        case .beer: "Beer"
        case .wine: "Wine"
        case .shot: "Shots"
        case .cocktail: "Cocktails"
        case .soft: "Soft drinks"
        }
    }

    /// The usual sizes, in ml; anything else goes in "Other". Cocktails have none.
    var sizeOptions: [Int] {
        switch self {
        case .beer: [330, 400, 500]
        case .wine: [100, 150, 750]
        case .shot: [20, 40]
        case .cocktail: []
        case .soft: [250, 330, 500]
        }
    }

    var defaultSizeMl: Int? {
        switch self {
        case .beer: Place.referenceBeerMl
        case .wine: 150
        case .shot: 40
        case .cocktail: nil
        case .soft: 330
        }
    }
}

enum DrinkFormat {
    /// "4 cl" for shots, "0.5 L" for the rest, as on Hungarian menus.
    static func size(_ ml: Int) -> String {
        if ml < 100 {
            return Measurement(value: Double(ml) / 10, unit: UnitVolume.centiliters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        }
        return Measurement(value: Double(ml) / 1000, unit: UnitVolume.liters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2))))
    }

    static func price(_ observation: PriceObservation) -> String {
        observation.amount.formatted(.currency(code: observation.currency).precision(.fractionLength(0)))
    }

    /// "today", "yesterday", "3 weeks ago": prices go stale, so their age is always shown.
    static func age(_ date: Date, now: Date = .now) -> String {
        if Calendar.current.isDate(date, inSameDayAs: now) { return String(localized: "today") }
        return date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }
}
