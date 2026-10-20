import SwiftUI

/// Minimal report for M1; full stats, map and sharing arrive in M4/M8.
struct ReportView: View {
    let night: Night

    var body: some View {
        List {
            if !night.trailPoints.isEmpty {
                Section {
                    TrailMap(night: night, isLive: false)
                        .frame(height: Theme.Size.reportMapHeight)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                LabeledContent("Duration", value: night.duration().durationText)
                LabeledContent("Beers", value: night.beerCount, format: .number)
                LabeledContent("Liters", value: night.liters, format: .number.precision(.fractionLength(1)))
                LabeledContent(
                    "Distance",
                    value: Measurement(value: TrailGeometry.walkedDistance(night.trailPoints), unit: UnitLength.meters),
                    format: .measurement(width: .abbreviated, usage: .road)
                )
            }
            EntryTimelineSection(night: night)
        }
        .navigationTitle(night.title)
    }
}
