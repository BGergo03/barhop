import SwiftUI

/// The trail as a plain line drawing (no map tiles), north up, fitted to its frame.
/// Used for the Home thumbnails and the share sticker.
struct TrailSketch: View {
    let segments: [[MapPoint]]
    let venues: [MapPoint]
    var color: Color = Theme.Palette.trail
    var gapColor: Color = Theme.Palette.trailGap
    var stroke: StrokeStyle = Theme.Stroke.thumbnailTrail
    var gapStroke: StrokeStyle = Theme.Stroke.thumbnailTrailGap
    var pinSize: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let projection = TrailProjection(
                fitting: segments.flatMap { $0 } + venues,
                in: size,
                inset: max(pinSize, stroke.lineWidth)
            )
            let points = segments.map { $0.map(projection.point(for:)) }
            context.stroke(path(TrailGeometry.gaps(between: points)), with: .color(gapColor), style: gapStroke)
            context.stroke(path(points), with: .color(color), style: stroke)
            guard pinSize > 0 else { return }
            for venue in venues {
                let center = projection.point(for: venue)
                let rect = CGRect(x: center.x - pinSize / 2, y: center.y - pinSize / 2, width: pinSize, height: pinSize)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }

    private func path(_ lines: [[CGPoint]]) -> Path {
        Path { path in
            for line in lines where line.count > 1 {
                path.addLines(line)
            }
        }
    }
}

extension Venue {
    var mapPoint: MapPoint { MapPoint(latitude: latitude, longitude: longitude) }
}
