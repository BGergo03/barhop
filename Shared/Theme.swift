import SwiftUI

/// Single source for every color, font, radius and spacing value in the app,
/// the widgets and the share renders.
///
/// Visual direction (SPEC §10): "Amber night" — a warm near-black canvas, one beer-amber
/// accent that glows, warm white text and rounded type throughout.
enum Theme {
    static let colorScheme: ColorScheme = .dark
    static let fontDesign: Font.Design = .rounded

    enum Palette {
        // Canvas
        static let background = Color(hex: 0x0B0A0C)
        static let surface = Color(hex: 0x17151A)
        static let surfaceRaised = Color(hex: 0x221F26)
        static let hairline = Color.white.opacity(0.07)

        // Accent
        static let accent = Color(hex: 0xFFB238)
        static let accentDeep = Color(hex: 0xE8801C)
        static let onAccent = Color(hex: 0x1C1206)
        static let glow = accent.opacity(0.45)
        static let danger = Color(hex: 0xFF5F52)

        // Text
        static let primaryText = Color(hex: 0xF6EFE4)
        static let secondaryText = primaryText.opacity(0.58)
        static let tertiaryText = primaryText.opacity(0.36)

        // Map
        static let trail = accent
        static let trailGap = primaryText.opacity(0.5)
        static let venuePin = accent
        static let venuePinRing = background

        // Live Activity
        static let activityBackground = background.opacity(0.88)

        // Share renders don't follow the device appearance, so they use fixed colors.
        static let shareBackground = background
        static let shareText = primaryText
        static let shareSecondaryText = secondaryText
        static let shareTrail = accent
        static let shareTrailGap = trailGap
        static let shareVenuePin = accent
        static let shareVenuePinRing = primaryText
        static let stickerText = Color.white
        static let stickerShadow = Color.black.opacity(0.45)
    }

    enum Gradients {
        static let accent = LinearGradient(colors: [Palette.accent, Palette.accentDeep], startPoint: .top, endPoint: .bottom)
        /// The warm light behind the Home hero and the share card header.
        static let backdropGlow = RadialGradient(
            colors: [Palette.accent.opacity(0.22), Palette.accent.opacity(0)],
            center: .top,
            startRadius: 0,
            endRadius: 420
        )
        /// Keeps the floating panels readable over a busy map.
        static let mapTopScrim = LinearGradient(colors: [Palette.background.opacity(0.85), Palette.background.opacity(0)], startPoint: .top, endPoint: .bottom)
        static let mapBottomScrim = LinearGradient(colors: [Palette.background.opacity(0), Palette.background.opacity(0.9)], startPoint: .top, endPoint: .bottom)
    }

    enum Typography {
        static let wordmark = Font.system(size: 22, weight: .heavy, design: fontDesign)
        static let screenTitle = Font.system(size: 34, weight: .bold, design: fontDesign)
        static let heroCount = Font.system(size: 64, weight: .bold, design: fontDesign).monospacedDigit()
        static let timer = Font.system(size: 28, weight: .semibold, design: fontDesign).monospacedDigit()
        static let statValue = Font.system(size: 26, weight: .bold, design: fontDesign).monospacedDigit()
        static let statLabel = Font.system(size: 12, weight: .semibold, design: fontDesign)
        static let sectionLabel = Font.system(size: 12, weight: .bold, design: fontDesign)
        static let headline = Font.system(.headline, design: fontDesign)
        static let body = Font.system(.body, design: fontDesign)
        static let caption = Font.system(.caption, design: fontDesign)
        static let primaryButton = Font.system(size: 20, weight: .bold, design: fontDesign)
        static let secondaryButton = Font.system(size: 15, weight: .semibold, design: fontDesign)
        static let venuePin = Font.system(size: 13, weight: .bold)
        static let emptyStateIcon = Font.system(size: 34, weight: .regular)
        static let activityCount = Font.system(size: 40, weight: .bold, design: fontDesign).monospacedDigit()
        static let activityTimer = Font.system(size: 17, weight: .semibold, design: fontDesign).monospacedDigit()
        static let activityButton = Font.system(size: 17, weight: .bold, design: fontDesign)
        static let compactTimer = Font.system(.body, design: fontDesign).monospacedDigit()
        static let activityUndo = Font.system(.caption, design: fontDesign).weight(.bold)

        static let shareWordmark = Font.system(size: 28, weight: .heavy, design: fontDesign)
        static let shareTitle = Font.system(size: 20, weight: .semibold, design: fontDesign)
        static let shareStatValue = Font.system(size: 34, weight: .bold, design: fontDesign).monospacedDigit()
        static let shareStatLabel = Font.system(size: 13, weight: .semibold, design: fontDesign)
        static let shareBody = Font.system(size: 15, weight: .medium, design: fontDesign)
        static let stickerStatValue = Font.system(size: 30, weight: .bold, design: fontDesign).monospacedDigit()

        /// Letter spacing for the small uppercase labels ("PAST NIGHTS", "BEERS").
        static let labelTracking: CGFloat = 1.2
        static let wordmarkTracking: CGFloat = 2
    }

    enum Radius {
        static let card: CGFloat = 22
        static let tile: CGFloat = 16
        static let thumbnail: CGFloat = 12
        static let shareMap: CGFloat = 20
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        /// Side margin of every screen.
        static let screen: CGFloat = 20
    }

    enum Size {
        static let primaryButtonHeight: CGFloat = 64
        static let beerButtonHeight: CGFloat = 76
        static let iconButton: CGFloat = 40
        static let reportMapHeight: CGFloat = 260
        /// Room the live map leaves for the floating stats panel and "+1 Beer" panel.
        static let liveMapTopInset: CGFloat = 190
        static let liveMapBottomInset: CGFloat = 220
        static let trailThumbnail = CGSize(width: 72, height: 56)
        static let venuePin: CGFloat = 26
        static let venuePinRing: CGFloat = 3
        static let placeIndex: CGFloat = 24
        static let hairline: CGFloat = 1
        /// `Text(_, style: .timer)` claims all available width; this keeps the Dynamic Island compact.
        static let compactTimerWidth: CGFloat = 52
        /// Same reason, for the night pill above the tab bar; fits "0:00:00".
        static let pillTimerWidth: CGFloat = 72
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

    enum Shadow {
        static let glowRadius: CGFloat = 22
        static let glowOffset: CGFloat = 8
        static let panelRadius: CGFloat = 24
        static let panel = Color.black.opacity(0.5)
    }

    enum Stroke {
        static let trail = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        static let trailGap = StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 8])
        static let thumbnailTrail = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        static let thumbnailTrailGap = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])
        static let shareTrail = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        static let shareTrailGap = StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 7])
    }

    enum Motion {
        static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
        static let pressedScale: CGFloat = 0.96
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
