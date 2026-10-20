import MapKit
import SwiftUI
import UIKit

/// A static map of the night for the share card: `MKMapSnapshotter` tiles with the trail
/// (solid segments, dashed gaps) and venue pins drawn on top (SPEC §9).
@MainActor
enum MapSnapshot {
    /// Extra room around the route, as a fraction of its span.
    private static let padding = 0.25
    /// Keeps a short route (or a single venue) from zooming in to street-sign level.
    private static let minimumSpanMeters: CLLocationDistance = 400

    static func image(for content: ShareContent, size: CGSize) async -> UIImage? {
        let coordinates = content.segments.flatMap { $0 } + content.venues
        guard !coordinates.isEmpty else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = region(fitting: coordinates)
        options.size = size
        options.scale = Theme.Size.shareRenderScale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.pointOfInterestFilter = .excludingAll

        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await MKMapSnapshotter(options: options).start()
        } catch {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = Theme.Size.shareRenderScale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            snapshot.image.draw(at: .zero)
            let cg = context.cgContext
            let segments = content.segments.map { $0.map { snapshot.point(for: $0.clCoordinate) } }

            stroke(TrailGeometry.gaps(between: segments), color: Theme.Palette.shareTrailGap, style: Theme.Stroke.shareTrailGap, in: cg)
            stroke(segments, color: Theme.Palette.shareTrail, style: Theme.Stroke.shareTrail, in: cg)

            let diameter = Theme.Size.shareMapPin
            for venue in content.venues {
                let center = snapshot.point(for: venue.clCoordinate)
                let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
                cg.setFillColor(UIColor(Theme.Palette.shareVenuePin).cgColor)
                cg.fillEllipse(in: rect)
                cg.setStrokeColor(UIColor(Theme.Palette.shareVenuePinRing).cgColor)
                cg.setLineWidth(Theme.Size.shareMapPinRing)
                cg.strokeEllipse(in: rect)
            }
        }
    }

    private static func region(fitting coordinates: [ShareContent.Coordinate]) -> MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min()!, maxLat = latitudes.max()!
        let minLon = longitudes.min()!, maxLon = longitudes.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let minimum = MKCoordinateRegion(center: center, latitudinalMeters: minimumSpanMeters, longitudinalMeters: minimumSpanMeters).span
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * (1 + 2 * padding), minimum.latitudeDelta),
            longitudeDelta: max((maxLon - minLon) * (1 + 2 * padding), minimum.longitudeDelta)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func stroke(_ lines: [[CGPoint]], color: Color, style: StrokeStyle, in cg: CGContext) {
        cg.saveGState()
        cg.setStrokeColor(UIColor(color).cgColor)
        cg.setLineWidth(style.lineWidth)
        cg.setLineCap(style.lineCap)
        cg.setLineJoin(style.lineJoin)
        cg.setLineDash(phase: style.dashPhase, lengths: style.dash)
        for line in lines where line.count > 1 {
            cg.addLines(between: line)
        }
        cg.strokePath()
        cg.restoreGState()
    }
}

extension ShareContent.Coordinate {
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
