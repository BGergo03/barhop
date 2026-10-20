import MapKit
import SwiftUI

/// The night's trail: solid segments, dashed connectors across tracking gaps, venue pins.
/// Tapping a pin selects its venue; the caller presents the rename sheet outside any `List`,
/// since a sheet presented from inside `List` content closes itself when the row is recreated.
struct TrailMap: View {
    let night: Night
    /// Live night follows the user; the report frames the whole trail.
    let isLive: Bool
    @Binding var selectedVenue: Venue?
    @State private var position: MapCameraPosition

    init(night: Night, isLive: Bool, selectedVenue: Binding<Venue?>) {
        self.night = night
        self.isLive = isLive
        _selectedVenue = selectedVenue
        _position = State(initialValue: isLive ? .userLocation(fallback: .automatic) : .automatic)
    }

    var body: some View {
        let segments = TrailGeometry.segments(night.trailPoints)
        let gaps = TrailGeometry.gaps(between: segments)
        Map(position: $position) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, coordinates in
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.Palette.trail, style: Theme.Stroke.trail)
            }
            ForEach(Array(gaps.enumerated()), id: \.offset) { _, coordinates in
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.Palette.trailGap, style: Theme.Stroke.trailGap)
            }
            ForEach(night.venues) { venue in
                Annotation(venue.name, coordinate: CLLocationCoordinate2D(latitude: venue.latitude, longitude: venue.longitude)) {
                    Button {
                        selectedVenue = venue
                    } label: {
                        VenuePin()
                    }
                }
            }
            if isLive {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            if isLive { MapUserLocationButton() }
            MapCompass()
        }
    }
}

/// An amber disc with a mug, ringed so it reads on any map.
struct VenuePin: View {
    var body: some View {
        Image(systemName: "mug.fill")
            .font(Theme.Typography.venuePin)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: Theme.Size.venuePin, height: Theme.Size.venuePin)
            .background(Theme.Gradients.accent, in: .circle)
            .overlay(Circle().strokeBorder(Theme.Palette.venuePinRing, lineWidth: Theme.Size.venuePinRing))
            .shadow(color: Theme.Palette.glow, radius: Theme.Spacing.small)
    }
}

/// One-line prompt shown instead of the map when location access is off (SPEC §7).
struct LocationOffPrompt: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
            Label("Location is off. Turn it on in Settings to map your night.", systemImage: "location.slash")
                .labelStyle(CompactLabelStyle())
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
