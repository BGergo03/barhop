import SwiftUI

/// Entries newest first; swipe to delete, tap to edit the time.
/// Shared by Live night and Report, so it lives inside the caller's `List`; the caller
/// presents the editor with `entryTimeEditor(_:)` outside the `List`.
struct EntryTimelineSection: View {
    let night: Night
    @Binding var editingEntry: Entry?
    @Environment(NightEngine.self) private var engine

    var body: some View {
        Section {
            if night.entries.isEmpty {
                EmptyStateRow(systemImage: "mug", message: "No beers yet")
                    .cardRow()
            }
            ForEach(night.sortedEntries) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    EntryRow(entry: entry)
                }
                .tint(Theme.Palette.primaryText)
                .cardRow()
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        engine.deleteEntry(entry)
                    }
                }
            }
        } header: {
            SectionLabel("Timeline")
        }
    }
}

extension View {
    /// Attach outside the `List`: a sheet presented from inside `List` content closes
    /// itself whenever the `List` recreates that content, e.g. when the night re-renders.
    func entryTimeEditor(_ entry: Binding<Entry?>) -> some View {
        sheet(item: entry) { entry in
            EditEntryTimeSheet(entry: entry)
        }
    }
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(Theme.Typography.headline.monospacedDigit())
                .foregroundStyle(Theme.Palette.accent)
            Label("Beer", systemImage: "mug.fill")
                .labelStyle(CompactLabelStyle())
                .font(Theme.Typography.body)
            Spacer()
            if let venue = entry.venue {
                Text(venue.name)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

private struct EditEntryTimeSheet: View {
    let entry: Entry
    let range: ClosedRange<Date>
    @Environment(NightEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date

    init(entry: Entry) {
        self.entry = entry
        self.range = entry.night?.entryTimeRange() ?? entry.timestamp...entry.timestamp
        _time = State(initialValue: entry.timestamp)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: $time, in: range, displayedComponents: [.date, .hourAndMinute])
                    .cardRow()
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Edit time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        engine.editEntryTime(entry, to: time)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.Palette.background)
    }
}
