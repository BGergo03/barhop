import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Barhop

struct ShareContentTests {
    static func content(venues: Int = 2, showsMap: Bool = true, withRoute: Bool = true) -> ShareContent {
        let origin = ShareContent.Coordinate(latitude: 47.4970, longitude: 19.0600)
        let east = ShareContent.Coordinate(latitude: 47.4970, longitude: 19.0700)
        let north = ShareContent.Coordinate(latitude: 47.5000, longitude: 19.0700)
        return ShareContent(
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            title: "Sat 24 Oct",
            duration: 4 * 3600,
            beers: 5,
            liters: 2.5,
            distance: withRoute ? 1800 : nil,
            venueNames: (0..<venues).map { "Bar \($0 + 1)" },
            segments: withRoute ? [[origin, east], [north]] : [],
            venues: withRoute ? [origin, north] : [],
            showsMap: showsMap
        )
    }

    @Test func fileNameUsesLocalStartDate() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        // 23:30 UTC on 24 Oct is already 25 Oct in Budapest.
        let date = try Date("2026-10-24T23:30:00Z", strategy: .iso8601)
        #expect(ShareContent.fileName(for: date, timeZone: timeZone) == "Barhop-2026-10-25.png")
    }

    @Test func venueListCollapsesAfterSix() {
        let few = Self.content(venues: 6).listedVenues
        #expect(few.names.count == 6)
        #expect(few.more == 0)

        let many = Self.content(venues: 9).listedVenues
        #expect(many.names == (1...6).map { "Bar \($0)" })
        #expect(many.more == 3)
    }

    @Test func mapNeedsToggleAndRoute() {
        #expect(Self.content().drawsMap)
        #expect(!Self.content(showsMap: false).drawsMap)
        #expect(!Self.content(withRoute: false).drawsMap)
    }

    @MainActor
    @Test func nightWithoutTrailHasNoDistance() {
        let night = Night(startedAt: Date(timeIntervalSince1970: 1_000_000))
        night.endedAt = night.startedAt.addingTimeInterval(3600)
        let content = ShareContent(night: night)
        #expect(content.distance == nil)
        #expect(!content.hasRoute)
        #expect(content.beers == 0)
    }
}

struct TrailProjectionTests {
    let size = CGSize(width: 200, height: 100)

    @Test func fitsInsideInsetKeepingNorthUp() {
        let south = ShareContent.Coordinate(latitude: 47.49, longitude: 19.06)
        let north = ShareContent.Coordinate(latitude: 47.50, longitude: 19.06)
        let projection = TrailProjection(fitting: [south, north], in: size, inset: 10)
        let top = projection.point(for: north)
        let bottom = projection.point(for: south)
        #expect(abs(top.y - 10) < 0.001)
        #expect(abs(bottom.y - 90) < 0.001)
        #expect(abs(top.x - 100) < 0.001)
    }

    @Test func keepsProportions() {
        // ~750 m east-west and ~750 m north-south should come out square, limited by the height.
        let a = ShareContent.Coordinate(latitude: 47.5, longitude: 19.06)
        let b = ShareContent.Coordinate(latitude: 47.5 + 750 / 111_000.0, longitude: 19.06 + 750 / (111_000 * cos(47.5 * .pi / 180)))
        let projection = TrailProjection(fitting: [a, b], in: size, inset: 0)
        let pa = projection.point(for: a)
        let pb = projection.point(for: b)
        #expect(abs(abs(pb.x - pa.x) - abs(pb.y - pa.y)) < 0.5)
        #expect(abs(abs(pb.y - pa.y) - 100) < 0.001)
    }

    @Test func singlePointSitsInTheMiddle() {
        let only = ShareContent.Coordinate(latitude: 47.5, longitude: 19.06)
        #expect(TrailProjection(fitting: [only], in: size, inset: 10).point(for: only) == CGPoint(x: 100, y: 50))
    }
}

@MainActor
struct ShareRendererTests {
    @Test func cardIsOpaque1080x1920() async throws {
        // Map hidden: the snapshot needs map tiles from the network.
        let png = try await ShareRenderer.png(.card, for: ShareContentTests.content(showsMap: false))
        let image = try #require(UIImage(data: png)?.cgImage)
        #expect(image.width == 1080)
        #expect(image.height == 1920)
        #expect(try alpha(atTopLeftOf: image) == 255)
    }

    @Test func stickerIsTransparent() async throws {
        let png = try await ShareRenderer.png(.sticker, for: ShareContentTests.content())
        let image = try #require(UIImage(data: png)?.cgImage)
        #expect(image.width == Int(Theme.Size.stickerWidth * Theme.Size.shareRenderScale))
        #expect(try alpha(atTopLeftOf: image) == 0)
    }

    @Test func toggleHidesStickerTrail() async throws {
        let withTrail = try #require(UIImage(data: try await ShareRenderer.png(.sticker, for: ShareContentTests.content()))?.cgImage)
        let without = try #require(UIImage(data: try await ShareRenderer.png(.sticker, for: ShareContentTests.content(showsMap: false)))?.cgImage)
        #expect(withTrail.height - without.height >= Int(Theme.Size.stickerTrail.height * Theme.Size.shareRenderScale))
    }

    @Test func fileIsNamedByDate() async throws {
        let content = ShareContentTests.content(showsMap: false)
        let url = try await ShareRenderer.file(.sticker, for: content)
        #expect(url.lastPathComponent == ShareContent.fileName(for: content.startedAt))
        #expect(FileManager.default.fileExists(atPath: url.path()))
    }

    private func alpha(atTopLeftOf image: CGImage) throws -> UInt8 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Draw so the image's top-left pixel lands on the 1×1 context.
        context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
        return pixel[3]
    }
}
