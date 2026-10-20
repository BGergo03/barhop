import SwiftUI

/// Fix-up for a venue's name: nearest places plus a custom name (SPEC §6), and the way to
/// the place it's linked to.
struct VenueSheet: View {
    let venue: Venue
    /// Called after the sheet dismisses itself, so the host can push the place.
    var openPlace: (Place) -> Void
    @Environment(NightEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [VenueCandidate]?
    @State private var customName = ""
    @State private var editsCustomName = false

    var body: some View {
        NavigationStack {
            List {
                if let place = venue.place {
                    Section {
                        Button("Open place", systemImage: "building.2") {
                            dismiss()
                            openPlace(place)
                        }
                        .cardRow()
                    }
                }
                Section {
                    if let candidates {
                        if candidates.isEmpty {
                            EmptyStateRow(systemImage: "mappin.slash", message: "No places found nearby")
                                .cardRow()
                        }
                        ForEach(candidates) { candidate in
                            Button {
                                engine.renameVenue(venue, to: candidate)
                                dismiss()
                            } label: {
                                CandidateRow(candidate: candidate, isCurrent: candidate.name == venue.name)
                            }
                            .tint(Theme.Palette.primaryText)
                            .cardRow()
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .cardRow()
                    }
                } header: {
                    SectionLabel("Nearby places")
                }
                Section {
                    Button("Custom name…", systemImage: "pencil") {
                        customName = venue.name
                        editsCustomName = true
                    }
                    .cardRow()
                }
            }
            .cardList()
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
        .presentationBackground(Theme.Palette.background)
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
