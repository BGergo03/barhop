import SwiftUI

/// Single source for every color, font, radius and spacing value in the app,
/// the widgets and the share renders. The visual direction is still OPEN
/// (SPEC §10), so these are system defaults that can be swapped here later.
enum Theme {
    static let colorScheme: ColorScheme = .dark

    enum Palette {
        static let accent = Color.accentColor
        static let onAccent = Color.white
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let background = Color(uiColor: .systemBackground)
        static let surface = Color(uiColor: .secondarySystemBackground)
    }

    enum Typography {
        static let heroCount = Font.system(size: 56, weight: .bold, design: .rounded)
        static let timer = Font.title2.monospacedDigit()
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let primaryButton = Font.title2.weight(.semibold)
    }

    enum Radius {
        static let button: CGFloat = 20
        static let card: CGFloat = 16
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Size {
        static let primaryButtonHeight: CGFloat = 72
    }
}
