import SwiftUI

/// Records a price seen at a place (SPEC §7). Opened from an existing drink, it starts filled
/// in, so a new price for the same drink is one field away.
struct AddPriceSheet: View {
    let place: Place
    @Environment(NightEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var category: DrinkCategory
    @State private var name: String
    @State private var size: SizeChoice
    @State private var otherSizeMl: Int?
    @State private var amount: Decimal?
    @FocusState private var focusedField: Field?

    private static let suggestionLimit = 6

    private enum Field {
        case name
        case price
    }

    private enum SizeChoice: Hashable {
        case none
        case ml(Int)
        case other
    }

    init(place: Place, drink: MenuItem? = nil) {
        self.place = place
        let category = drink?.category ?? .beer
        let sizeMl = drink == nil ? category.defaultSizeMl : drink?.sizeMl
        _category = State(initialValue: category)
        _name = State(initialValue: drink?.name ?? "")
        _size = State(initialValue: Self.choice(for: sizeMl, in: category))
        _otherSizeMl = State(initialValue: sizeMl.flatMap { category.sizeOptions.contains($0) ? nil : $0 })
    }

    private static func choice(for sizeMl: Int?, in category: DrinkCategory) -> SizeChoice {
        guard let sizeMl else { return .none }
        return category.sizeOptions.contains(sizeMl) ? .ml(sizeMl) : .other
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var sizeMl: Int? {
        switch size {
        case .none: nil
        case .ml(let ml): ml
        case .other: otherSizeMl
        }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && (amount ?? 0) > 0 && (size != .other || (otherSizeMl ?? 0) > 0)
    }

    private var suggestions: [String] {
        engine.places.nameSuggestions(for: category)
            .filter { trimmedName.isEmpty || ($0.localizedStandardContains(trimmedName) && !PlaceLinker.isSameName($0, trimmedName)) }
            .prefix(Self.suggestionLimit)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(DrinkCategory.allCases, id: \.self) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .cardRow()
                    TextField("Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .price }
                        .cardRow()
                    if !suggestions.isEmpty {
                        suggestionChips
                            .cardRow()
                    }
                }
                Section {
                    Picker("Size", selection: $size) {
                        if category.sizeOptions.isEmpty {
                            Text("No size").tag(SizeChoice.none)
                        }
                        ForEach(category.sizeOptions, id: \.self) { ml in
                            Text(DrinkFormat.size(ml)).tag(SizeChoice.ml(ml))
                        }
                        Text("Other").tag(SizeChoice.other)
                    }
                    .cardRow()
                    if size == .other {
                        LabeledContent("Size in ml") {
                            TextField("ml", value: $otherSizeMl, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        .cardRow()
                    }
                }
                Section {
                    LabeledContent("Price") {
                        HStack(spacing: Theme.Spacing.xSmall) {
                            TextField("0", value: $amount, format: .number)
                                .focused($focusedField, equals: .price)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text(verbatim: "Ft")
                                .foregroundStyle(Theme.Palette.secondaryText)
                        }
                    }
                    .cardRow()
                } footer: {
                    Text("Saved as seen today. An older price for the same drink stays in its history.")
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Add a price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: category) { _, category in
                size = Self.choice(for: category.defaultSizeMl, in: category)
                otherSizeMl = nil
            }
            .onAppear { focusedField = name.isEmpty ? .name : .price }
        }
        .presentationBackground(Theme.Palette.background)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.small) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        name = suggestion
                        focusedField = .price
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        guard canSave, let amount else { return }
        engine.places.addPrice(to: place, category: category, name: trimmedName, sizeMl: sizeMl, amount: amount)
        dismiss()
    }
}
