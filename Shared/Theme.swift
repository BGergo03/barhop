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
        static let trail = Color.accentColor
        static let trailGap = Color.secondary
        static let venuePin = Color.orange
        static let activityBackground = Color.black.opacity(0.6)
        /// Share renders don't follow the device appearance, so they use fixed colors.
        static let shareBackground = Color(red: 0.07, green: 0.07, blue: 0.09)
        static let shareText = Color.white
        static let shareSecondaryText = Color.white.opacity(0.7)
        static let shareTrail = Color.orange
        static let shareTrailGap = Color.white.opacity(0.6)
        static let shareVenuePin = Color.orange
        static let shareVenuePinRing = Color.white
        static let stickerShadow = Color.black.opacity(0.45)
    }

    enum Typography {
        static let heroCount = Font.system(size: 56, weight: .bold, design: .rounded)
        static let timer = Font.title2.monospacedDigit()
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let primaryButton = Font.title2.weight(.semibold)
        static let venuePin = Font.title
        static let activityCount = Font.system(size: 40, weight: .bold, design: .rounded)
        static let activityButton = Font.headline
        static let compactTimer = Font.body.monospacedDigit()
        static let activityUndo = Font.caption.weight(.semibold)
        static let shareWordmark = Font.system(size: 28, weight: .heavy, design: .rounded)
        static let shareTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let shareStatValue = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
        static let shareStatLabel = Font.system(size: 13, weight: .medium, design: .rounded)
        static let shareBody = Font.system(size: 15, weight: .medium, design: .rounded)
        static let stickerStatValue = Font.system(size: 30, weight: .bold, design: .rounded).monospacedDigit()
    }

    enum Radius {
        static let button: CGFloat = 20
        static let card: CGFloat = 16
        static let shareMap: CGFloat = 20
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Size {
        static let primaryButtonHeight: CGFloat = 72
        static let liveMapHeight: CGFloat = 280
        static let reportMapHeight: CGFloat = 240
        /// `Text(_, style: .timer)` claims all available width; this keeps the Dynamic Island compact.
        static let compactTimerWidth: CGFloat = 52
        /// 1080×1920 px at the 3× render scale.
        static let shareCard = CGSize(width: 360, height: 640)
        static let shareCardPadding: CGFloat = 28
        static let shareMapHeight: CGFloat = 260
        static let stickerWidth: CGFloat = 320
        static let stickerTrail = CGSize(width: 260, height: 220)
        static let stickerPin: CGFloat = 8
        static let shareMapPin: CGFloat = 14
        static let shareMapPinRing: CGFloat = 3
        static let stickerShadowRadius: CGFloat = 4
        static let shareRenderScale: CGFloat = 3
    }

    enum Stroke {
        static let trail = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        static let trailGap = StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 8])
        static let shareTrail = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        static let shareTrailGap = StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 7])
    }
}
