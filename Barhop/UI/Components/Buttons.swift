import SwiftUI

/// The glowing amber capsule for the one main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = Theme.Size.primaryButtonHeight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.primaryButton)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.Gradients.accent, in: .capsule)
            .shadow(color: Theme.Palette.glow, radius: Theme.Shadow.glowRadius, y: Theme.Shadow.glowOffset)
            .scaleEffect(configuration.isPressed ? Theme.Motion.pressedScale : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

/// A quiet capsule for secondary actions ("End night", "Timeline").
struct SecondaryButtonStyle: ButtonStyle {
    var role: ButtonRole?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.secondaryButton)
            .foregroundStyle(role == .destructive ? Theme.Palette.danger : Theme.Palette.primaryText)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small + Theme.Spacing.xSmall / 2)
            .background(Theme.Palette.surfaceRaised, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline))
            .scaleEffect(configuration.isPressed ? Theme.Motion.pressedScale : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

/// A small amber capsule, e.g. the night pill's "+1".
struct AccentCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.secondaryButton)
            .foregroundStyle(Theme.Palette.onAccent)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.xSmall)
            .background(Theme.Gradients.accent, in: .capsule)
            .scaleEffect(configuration.isPressed ? Theme.Motion.pressedScale : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

/// Round glyph button, e.g. the Settings gear.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Palette.primaryText)
            .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
            .background(Theme.Palette.surfaceRaised, in: .circle)
            .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline))
            .scaleEffect(configuration.isPressed ? Theme.Motion.pressedScale : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(height: CGFloat) -> PrimaryButtonStyle { PrimaryButtonStyle(height: height) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var destructiveSecondary: SecondaryButtonStyle { SecondaryButtonStyle(role: .destructive) }
}

extension ButtonStyle where Self == AccentCapsuleButtonStyle {
    static var accentCapsule: AccentCapsuleButtonStyle { AccentCapsuleButtonStyle() }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}
