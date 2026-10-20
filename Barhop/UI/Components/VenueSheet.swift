import SwiftUI

/// Fix-up for a venue's name: nearest places plus a custom name (SPEC §6).
struct VenueSheet: View {
    let venue: Venue
    @Environment(NightEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [VenueCandidate]?
    @State private var customName = ""
    @State private var editsCustomName = false

    var body: some View {
        NavigationStack {
            List {
                Section("Nearby places") {
                    if let candidates {
                        if candidates.isEmpty {
                            Text("No places found nearby")
                                .foregroundStyle(Theme.Palette.secondaryText)
                        }
                        ForEach(candidates) { candidate in
                            Button {
                                rename(to: candidate.name)
                            } label: {
                                CandidateRow(candidate: candidate, isCurrent: candidate.name == venue.name)
                            }
                            .tint(Theme.Palette.primaryText)
                        }
                    } else {
                        ProgressView()
                    }
                }
                Section {
                    Button("Custom name…") {
                        customName = venue.name
                        editsCustomName = true
                    }
                }
            }
            .navigationTitle(venue.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .task {
                candidates = await engine.nameCandidates(for: venue)
            }
            .alert("Custom name", isPresented: $editsCustomName) {
                TextField("Name", text: $customName)
                Button("Save") {
                    let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { rename(to: name) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func rename(to name: String) {
        engine.renameVenue(venue, to: name)
        dismiss()
    }
}

private struct CandidateRow: View {
    let candidate: VenueCandidate
    let isCurrent: Bool

    var body: some View {
        HStack {
            Text(candidate.name)
            Spacer()
            Text(Measurement(value: candidate.distance, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }
}
