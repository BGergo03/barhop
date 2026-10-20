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
                BeerCount(count: context.state.beerCount)
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(Theme.Typography.compactTimer)
                    .foregroundStyle(Theme.Palette.accent)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: Theme.Size.compactTimerWidth)
            } minimal: {
                BeerCount(count: context.state.beerCount)
            }
            .keylineTint(Theme.Palette.accent)
        }
    }
}

/// Mug glyph in amber next to the count.
private struct BeerCount: View {
    let count: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xSmall / 2) {
            Image(systemName: "mug.fill")
                .foregroundStyle(Theme.Palette.accent)
            Text(count, format: .number)
                .foregroundStyle(Theme.Palette.primaryText)
        }
        .fontDesign(Theme.fontDesign)
        .fontWeight(.bold)
    }
}

/// The Lock Screen layout, reused as the expanded Dynamic Island (SPEC §8).
private struct NightActivityContent: View {
    let context: ActivityViewContext<NightActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(alignment: .center, spacing: Theme.Spacing.medium) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xSmall / 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
                        Text(context.state.beerCount, format: .number)
                            .font(Theme.Typography.activityCount)
                            .foregroundStyle(Theme.Gradients.accent)
                            .contentTransition(.numericText())
                        Text(context.attributes.startedAt, style: .timer)
                            .font(Theme.Typography.activityTimer)
                            .foregroundStyle(Theme.Palette.primaryText)
                    }
                    if let venue = context.state.currentVenueName {
                        Label(venue, systemImage: "mappin")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button(intent: LogBeerIntent()) {
                    Label("+1 Beer", systemImage: "mug.fill")
                        .font(Theme.Typography.activityButton)
                        .foregroundStyle(Theme.Palette.onAccent)
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.vertical, Theme.Spacing.small + Theme.Spacing.xSmall / 2)
                        .background(Theme.Gradients.accent, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            if let undoUntil = context.state.undoUntil, undoUntil > .now {
                HStack(spacing: Theme.Spacing.xSmall) {
                    Text("Added Beer ·")
                        .foregroundStyle(Theme.Palette.secondaryText)
                    Button(intent: UndoLastEntryIntent(entryID: context.state.lastEntryID)) {
                        Text("Undo")
                            .font(Theme.Typography.activityUndo)
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    .buttonStyle(.plain)
                }
                .font(Theme.Typography.caption)
            }
        }
        .fontDesign(Theme.fontDesign)
    }
}
