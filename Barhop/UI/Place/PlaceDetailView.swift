import MapKit
import SwiftUI

/// A lasting place: where it is, what it serves and for how much, and your visits (SPEC §7).
struct PlaceDetailView: View {
    let place: Place
    @Environment(NightEngine.self) private var engine
    @State private var priceSheet: PriceSheetRequest?

    /// `drink` is the menu item to add a new price for, `nil` for a new drink.
    private struct PriceSheetRequest: Identifiable {
        let id = UUID()
        var drink: MenuItem?
    }

    var body: some View {
        List {
            Section {
                header
                    .bareRow()
            }
            Section {
                PlaceMap(place: place)
                    .frame(height: Theme.Size.placeMapHeight)
                    .listRowInsets(EdgeInsets())
                    .cardRow()
            }
            menuSections
            visitsSection
        }
        .cardList()
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                priceSheet = PriceSheetRequest()
            } label: {
                Label("Add a price", systemImage: "plus")
            }
        }
        // Outside the List, so it survives the List re-rendering when the price is saved.
        .sheet(item: $priceSheet) { request in
            AddPriceSheet(place: place, drink: request.drink)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                Text(place.name)
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.Palette.primaryText)
                if let address = place.address {
                    Text(address)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
            HStack(spacing: Theme.Spacing.small) {
                Button {
                    engine.places.setSaved(!place.isSaved, for: place)
                } label: {
                    Label(place.isSaved ? "Saved" : "Save", systemImage: place.isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.secondary)
                .sensoryFeedback(.selection, trigger: place.isSaved)
                Button {
                    Task { await PlaceMap.openInMaps(place) }
                } label: {
                    Label("Open in Maps", systemImage: "map")
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.small)
    }

    @ViewBuilder
    private var menuSections: some View {
        let groups = place.menuByCategory
        Section {
            if groups.isEmpty {
                EmptyStateRow(systemImage: "menucard", message: "No drinks yet. Add what you see on the menu.")
                    .cardRow()
            }
            Button("Add a price", systemImage: "plus") {
                priceSheet = PriceSheetRequest()
            }
            .cardRow()
        } header: {
            SectionLabel("Menu")
        }
        ForEach(groups, id: \.category) { group in
            Section {
                ForEach(group.items) { item in
                    Button {
                        priceSheet = PriceSheetRequest(drink: item)
                    } label: {
                        MenuItemRow(item: item)
                    }
                    .tint(Theme.Palette.primaryText)
                    .cardRow()
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            engine.places.deleteMenuItem(item)
                        }
                    }
                }
            } header: {
                SectionLabel(Text(group.category.sectionTitle))
            }
        }
    }

    private var visitsSection: some View {
        Section {
            if place.visits.isEmpty {
                EmptyStateRow(systemImage: "mappin.and.ellipse", message: "Your visits will show up here.")
                    .cardRow()
            }
            ForEach(place.visits) { stop in
                if let night = stop.night {
                    NavigationLink(value: Route.report(night)) {
                        VisitRow(night: night, stop: stop)
                    }
                    .cardRow()
                }
            }
        } header: {
            SectionLabel("Your visits")
        }
    }
}

/// A still map of the place with its pin.
private struct PlaceMap: View {
    let place: Place

    private static let cameraDistance: Double = 700

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    var body: some View {
        Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: Self.cameraDistance)), interactionModes: []) {
            Annotation(place.name, coordinate: coordinate) {
                VenuePin()
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
    }

    /// The Apple Maps page for the place when Maps knows it, else a pin at its coordinate.
    static func openInMaps(_ place: Place) async {
        if let rawIdentifier = place.mapItemIdentifier,
           let identifier = MKMapItem.Identifier(rawValue: rawIdentifier),
           let item = try? await MKMapItemRequest(mapItemIdentifier: identifier).mapItem {
            item.openInMaps()
            return
        }
        let item = MKMapItem(location: CLLocation(latitude: place.latitude, longitude: place.longitude), address: nil)
        item.name = place.name
        item.openInMaps()
    }
}

private struct MenuItemRow: View {
    let item: MenuItem

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall / 2) {
                Text(item.name)
                    .font(Theme.Typography.body)
                if let sizeMl = item.sizeMl {
                    Text(DrinkFormat.size(sizeMl))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
            Spacer()
            if let price = item.latestPrice {
                VStack(alignment: .trailing, spacing: Theme.Spacing.xSmall / 2) {
                    Text(DrinkFormat.price(price))
                        .font(Theme.Typography.headline.monospacedDigit())
                        .foregroundStyle(Theme.Palette.accent)
                    Text(DrinkFormat.age(price.seenAt))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
        }
    }
}

private struct VisitRow: View {
    let night: Night
    let stop: Venue

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall / 2) {
                Text(night.title)
                    .font(Theme.Typography.body)
                Text(stop.arrivedAt, format: .dateTime.hour().minute())
                    .font(Theme.Typography.caption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            Text(((stop.leftAt ?? night.endedAt ?? stop.arrivedAt).timeIntervalSince(stop.arrivedAt)).durationText)
                .font(Theme.Typography.body.monospacedDigit())
                .foregroundStyle(Theme.Palette.secondaryText)
        }
    }
}
