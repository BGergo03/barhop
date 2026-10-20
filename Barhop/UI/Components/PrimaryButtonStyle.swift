import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.primaryButton)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
            .background(Theme.Palette.accent, in: .rect(cornerRadius: Theme.Radius.button))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
