import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct NightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightActivityAttributes.self) { context in
            NightActivityContent(context: context)
                .padding(Theme.Spacing.medium)
                .activityBackgroundTint(Theme.Palette.activityBackground)
                .activitySystemActionForegroundColor(Theme.Palette.primaryText)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    NightActivityContent(context: context)
                }
            } compactLeading: {
                Text("🍺 \(context.state.beerCount)")
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(Theme.Typography.compactTimer)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: Theme.Size.compactTimerWidth)
            } minimal: {
                Text(context.state.beerCount, format: .number)
            }
        }
    }
}

/// The Lock Screen layout, reused as the expanded Dynamic Island (SPEC §8).
private struct NightActivityContent: View {
    let context: ActivityViewContext<NightActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(alignment: .center, spacing: Theme.Spacing.medium) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
                    Text("🍺 \(context.state.beerCount)")
                        .font(Theme.Typography.activityCount)
                        .contentTransition(.numericText())
                    Text(context.attributes.startedAt, style: .timer)
                        .font(Theme.Typography.timer)
                    if let venue = context.state.currentVenueName {
                        Text(venue)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button(intent: LogBeerIntent()) {
                    Text("+1 Beer")
                        .font(Theme.Typography.activityButton)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.Palette.accent)
            }
            if let undoUntil = context.state.undoUntil, undoUntil > .now {
                HStack(spacing: Theme.Spacing.small / 2) {
                    Text("Added Beer ·")
                        .foregroundStyle(Theme.Palette.secondaryText)
                    Button(intent: UndoLastEntryIntent(entryID: context.state.lastEntryID)) {
                        Text("Undo")
                            .font(Theme.Typography.activityUndo)
                    }
                    .buttonStyle(.plain)
                }
                .font(Theme.Typography.caption)
            }
        }
    }
}
