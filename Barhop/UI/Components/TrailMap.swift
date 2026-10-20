import MapKit
import SwiftUI

/// The night's trail: solid segments, dashed connectors across tracking gaps, venue pins.
/// Tapping a pin opens the rename sheet.
struct TrailMap: View {
    let night: Night
    /// Live night follows the user; the report frames the whole trail.
    let isLive: Bool
    @State private var position: MapCameraPosition
    @State private var selectedVenue: Venue?

    init(night: Night, isLive: Bool) {
        self.night = night
        self.isLive = isLive
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
                        Image(systemName: "mappin.circle.fill")
                            .font(Theme.Typography.venuePin)
                            .foregroundStyle(Theme.Palette.onAccent, Theme.Palette.venuePin)
                    }
                }
            }
            if isLive {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            if isLive { MapUserLocationButton() }
            MapCompass()
        }
        .sheet(item: $selectedVenue) { venue in
            VenueSheet(venue: venue)
        }
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
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
    }
}
