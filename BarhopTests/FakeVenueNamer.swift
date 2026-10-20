import Foundation
@testable import Barhop

@MainActor
final class FakeVenueNamer: VenueNaming {
    var candidates: [VenueCandidate] = []
    var address: String?

    func candidates(latitude: Double, longitude: Double, limit: Int) async -> [VenueCandidate] {
        Array(candidates.prefix(limit))
    }

    func address(latitude: Double, longitude: Double) async -> String? {
        address
    }
}
