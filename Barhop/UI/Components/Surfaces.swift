import SwiftUI

extension View {
    /// The app's canvas: warm near-black, with the dark color scheme and amber tint.
    func screenBackground() -> some View {
        background(Theme.Palette.background.ignoresSafeArea())
    }

    /// A `List` drawn as floating cards on the canvas. Keeps swipe actions working.
    func cardList() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(Theme.Spacing.medium)
            .screenBackground()
    }

    /// A standalone card: padded surface with a hairline edge.
    func card(padding: CGFloat = Theme.Spacing.medium) -> some View {
        self.padding(padding)
            .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline))
    }

    /// A frosted panel floating over the map.
    func floatingPanel() -> some View {
        self.padding(Theme.Spacing.medium)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline))
            .shadow(color: Theme.Shadow.panel, radius: Theme.Shadow.panelRadius)
    }

    /// Row styling for `cardList()` rows.
    func cardRow() -> some View {
        listRowBackground(Theme.Palette.surface)
            .listRowSeparatorTint(Theme.Palette.hairline)
    }

    /// A plain `List` on the canvas whose rows are separate floating cards (see `floatingCardRow()`).
    /// Unlike `cardList()`, rows aren't clipped, so glows can spill past them.
    func floatingCardList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .screenBackground()
    }

    /// One card per row in a `floatingCardList()`. Swipe actions still work.
    func floatingCardRow() -> some View {
        listRowInsets(EdgeInsets(
            top: Theme.Spacing.medium,
            leading: Theme.Spacing.screen + Theme.Spacing.medium,
            bottom: Theme.Spacing.medium,
            trailing: Theme.Spacing.screen + Theme.Spacing.medium
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Palette.surface)
                .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.vertical, Theme.Spacing.xSmall)
        )
    }

    /// A row of a `floatingCardList()` with nothing behind it, e.g. a header or the hero.
    func floatingBareRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.screen, bottom: 0, trailing: Theme.Spacing.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// A list row with no card behind it, e.g. a hero or a button.
    func bareRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }
}

/// Small uppercase label above a group ("PAST NIGHTS").
struct SectionLabel: View {
    let title: Text

    init(_ title: LocalizedStringKey) {
        self.title = Text(title)
    }

    /// For titles that aren't literals, e.g. a drink category's.
    init(_ title: Text) {
        self.title = title
    }

    var body: some View {
        title
            .textCase(.uppercase)
            .font(Theme.Typography.sectionLabel)
            .tracking(Theme.Typography.labelTracking)
            .foregroundStyle(Theme.Palette.secondaryText)
    }
}

/// One stat: big number, small uppercase label.
struct StatTile: View {
    let label: LocalizedStringKey
    let value: Text
    var accented = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            value
                .font(Theme.Typography.statValue)
                .foregroundStyle(accented ? Theme.Palette.accent : Theme.Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .textCase(.uppercase)
                .font(Theme.Typography.statLabel)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A centered glyph and line of text for an empty list.
struct EmptyStateRow: View {
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            Image(systemName: systemImage)
                .font(Theme.Typography.emptyStateIcon)
                .foregroundStyle(Theme.Palette.accent)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.large)
    }
}

/// "BARHOP", spaced out, in amber.
struct Wordmark: View {
    var body: some View {
        Text("Barhop")
            .textCase(.uppercase)
            .font(Theme.Typography.wordmark)
            .tracking(Theme.Typography.wordmarkTracking)
            .foregroundStyle(Theme.Gradients.accent)
    }
}
