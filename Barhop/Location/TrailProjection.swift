import CoreGraphics
import Foundation

/// A plain coordinate, so trail drawings can be built off the SwiftData context.
struct MapPoint: Sendable, Equatable {
    var latitude: Double
    var longitude: Double
}

/// Projects the trail into a fixed box for the sticker, north up, keeping its proportions.
struct TrailProjection {
    let size: CGSize
    private let center: MapPoint
    /// Points per degree of latitude; longitude is scaled by cos(latitude) on top.
    private let scale: Double
    private let longitudeFactor: Double

    /// - Parameters:
    ///   - coordinates: everything that must fit (trail and venues).
    ///   - size: the box; the trail is centered in it.
    ///   - inset: margin kept free on every side, e.g. for line width and pins.
    init(fitting coordinates: [MapPoint], in size: CGSize, inset: CGFloat) {
        self.size = size
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? 0, maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0, maxLon = longitudes.max() ?? 0
        center = .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        longitudeFactor = cos(center.latitude * .pi / 180)
        let spanY = maxLat - minLat
        let spanX = (maxLon - minLon) * longitudeFactor
        let available = (width: max(1, Double(size.width - 2 * inset)), height: max(1, Double(size.height - 2 * inset)))
        let candidates = [spanX > 0 ? available.width / spanX : nil, spanY > 0 ? available.height / spanY : nil].compactMap { $0 }
        // A single point (or nothing) just sits in the middle.
        scale = candidates.min() ?? 0
    }

    func point(for coordinate: MapPoint) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (coordinate.longitude - center.longitude) * longitudeFactor * scale,
            y: size.height / 2 - (coordinate.latitude - center.latitude) * scale
        )
    }
}
