import Foundation
import Testing
@testable import Barhop

struct PlaceLinkerTests {
    let placeID = UUID()

    func place(_ name: String = "Szimpla Kert", identifier: String? = nil, north: Double = 0) -> PlaceLinker.KnownPlace {
        let fix = testFix(0, north: north)
        return PlaceLinker.KnownPlace(id: placeID, mapItemIdentifier: identifier, name: name, latitude: fix.latitude, longitude: fix.longitude)
    }

    func candidate(_ name: String = "Szimpla Kert", identifier: String? = nil, north: Double = 0) -> VenueCandidate {
        let fix = testFix(0, north: north)
        return VenueCandidate(name: name, latitude: fix.latitude, longitude: fix.longitude, distance: 0, mapItemIdentifier: identifier)
    }

    @Test func sameIdentifierMatchesWhateverTheNameAndDistance() {
        let match = PlaceLinker.match(candidate("Szimpla", identifier: "I1", north: 500), among: [place(identifier: "I1")])
        #expect(match == .existing(placeID))
    }

    @Test func sameNameNearbyMatchesWithoutIdentifier() {
        let match = PlaceLinker.match(candidate(north: 60), among: [place()])
        #expect(match == .existing(placeID))
    }

    @Test func candidateIdentifierCanMatchPlaceStoredWithoutOne() {
        let match = PlaceLinker.match(candidate(identifier: "I1", north: 30), among: [place()])
        #expect(match == .existing(placeID))
    }

    @Test func sameNameJustOutsideRadiusIsNew() {
        let match = PlaceLinker.match(candidate(north: 76), among: [place()])
        #expect(match == .create)
    }

    @Test func differentNameNearbyIsNew() {
        let match = PlaceLinker.match(candidate("Instant"), among: [place()])
        #expect(match == .create)
    }

    @Test func differentIdentifiersNeverMatch() {
        let match = PlaceLinker.match(candidate(identifier: "I2"), among: [place(identifier: "I1")])
        #expect(match == .create)
    }

    @Test func namesCompareIgnoringCaseAccentsAndSpaces() {
        #expect(PlaceLinker.isSameName("Füge Udvar ", "fuge udvar"))
        #expect(!PlaceLinker.isSameName("Füge Udvar", "Füge"))
    }
}
