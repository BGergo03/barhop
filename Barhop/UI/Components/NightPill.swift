import SwiftUI

/// The night in progress, above the tab bar: count, timer and a quick +1.
/// Tapping anywhere else reopens Live night.
struct NightPill: View {
    let night: Night
    @Environment(NightEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Label {
                Text(night.beerCount, format: .number)
                    .contentTransition(.numericText())
                    .animation(.default, value: night.beerCount)
            } icon: {
                Image(systemName: "mug.fill")
            }
            .labelStyle(CompactLabelStyle())
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Palette.primaryText)

            Text(night.startedAt, style: .timer)
                .font(Theme.Typography.compactTimer)
                .foregroundStyle(Theme.Palette.primaryText)
                .frame(width: Theme.Size.pillTimerWidth, alignment: .leading)

            // The collapsed pill, next to a minimized tab bar, has no room for the venue.
            if placement != .inline, let venue = night.currentVenue {
                Text(venue.name)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("+1") {
                engine.logBeer()
            }
            .buttonStyle(.accentCapsule)
            .sensoryFeedback(.success, trigger: night.beerCount)
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .contentShape(.rect)
        .onTapGesture {
            router.openLiveNight(night)
        }
        .accessibilityAction(named: "Open night") {
            router.openLiveNight(night)
        }
    }
}
