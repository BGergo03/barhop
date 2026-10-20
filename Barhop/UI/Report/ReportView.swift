import SwiftUI

/// Minimal report for M1; full stats, map and sharing arrive in M4/M8.
struct ReportView: View {
    let night: Night

    var body: some View {
        List {
            Section {
                LabeledContent("Duration", value: night.duration().durationText)
                LabeledContent("Beers", value: night.beerCount, format: .number)
                LabeledContent("Liters", value: night.liters, format: .number.precision(.fractionLength(1)))
            }
            EntryTimelineSection(night: night)
        }
        .navigationTitle(night.title)
    }
}
