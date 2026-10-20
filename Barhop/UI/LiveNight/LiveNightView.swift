import SwiftUI

struct LiveNightView: View {
    let night: Night
    @Environment(NightEngine.self) private var engine
    @State private var confirmsEnd = false

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            header
            Button("+1 Beer") {
                engine.logBeer()
            }
            .buttonStyle(.primary)
            .sensoryFeedback(.success, trigger: night.beerCount)
            .padding(.horizontal, Theme.Spacing.medium)

            List {
                EntryTimelineSection(night: night)
            }
        }
        .navigationTitle(night.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("End night", role: .destructive) {
                confirmsEnd = true
            }
        }
        .confirmationDialog("End this night?", isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button("End night", role: .destructive) {
                engine.endNight(night)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small / 2) {
                Text(night.startedAt, style: .timer)
                    .font(Theme.Typography.timer)
                if let venue = night.currentVenue {
                    Text(venue.name)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
            Spacer()
            Text("🍺 \(night.beerCount)")
                .font(Theme.Typography.heroCount)
                .contentTransition(.numericText())
                .animation(.default, value: night.beerCount)
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.top, Theme.Spacing.medium)
    }
}
