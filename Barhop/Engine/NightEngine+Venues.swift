import Foundation
import SwiftData

/// Venue detection, provisional venues and naming (SPEC §6).
extension NightEngine {
    private static let candidateLimit = 5

    func renameVenue(_ venue: Venue, to name: String) {
        venue.name = name
        venue.nameSource = .user
        save()
    }

    /// Nearby name suggestions for the fix-up sheet.
    func nameCandidates(for venue: Venue) async -> [VenueCandidate] {
        await namer.candidates(latitude: venue.latitude, longitude: venue.longitude, limit: Self.candidateLimit)
    }

    func handleStopEvents(_ events: [StopDetector.Event], in night: Night) {
        for event in events {
            switch event {
            case let .arrived(center, at):
                if let open = night.currentVenue {
                    if open.distance(toLatitude: center.latitude, longitude: center.longitude) <= StopDetector.radius {
                        // The stay confirmed a provisional venue created by a beer: keep that one.
                        open.arrivedAt = min(open.arrivedAt, at)
                        open.latitude = center.latitude
                        open.longitude = center.longitude
                        save()
                        autoName(open)
                        continue
                    }
                    open.leftAt = max(open.arrivedAt, at)
                }
                createVenue(in: night, latitude: center.latitude, longitude: center.longitude, arrivedAt: at)
            case let .moved(center):
                guard let open = night.currentVenue else { continue }
                open.latitude = center.latitude
                open.longitude = center.longitude
                save()
            case let .left(at):
                closeOpenVenue(of: night, at: at)
            }
        }
    }

    /// Attaches an entry to the venue it was logged in, creating a provisional venue at the
    /// entry's location if it wasn't logged inside one.
    func assignVenue(to entry: Entry, at fix: LocationFix, in night: Night) {
        if let open = night.currentVenue {
            if open.distance(toLatitude: fix.latitude, longitude: fix.longitude) <= StopDetector.radius {
                entry.venue = open
                return
            }
            closeOpenVenue(of: night, at: entry.timestamp)
        }
        var arrivedAt = entry.timestamp
        if trackedNight == night {
            arrivedAt = min(arrivedAt, stopDetector.anchor(at: fix))
        }
        entry.venue = createVenue(in: night, latitude: fix.latitude, longitude: fix.longitude, arrivedAt: arrivedAt)
    }

    func closeOpenVenue(of night: Night, at date: Date) {
        guard let open = night.currentVenue else { return }
        open.leftAt = max(open.arrivedAt, date)
        save()
    }

    @discardableResult
    private func createVenue(in night: Night, latitude: Double, longitude: Double, arrivedAt: Date) -> Venue {
        // Placeholder until the lookup finishes, and the final name if it finds nothing (offline).
        let placeholder = String(localized: "Stop \(night.venues.count + 1)")
        let venue = Venue(name: placeholder, nameSource: .auto, latitude: latitude, longitude: longitude, arrivedAt: arrivedAt)
        context.insert(venue)
        venue.night = night
        save()
        autoName(venue)
        return venue
    }

    /// Nearest nightlife POI, else the street address. Never overrides a name the user picked.
    private func autoName(_ venue: Venue) {
        guard venue.nameSource != .user else { return }
        let venueID = venue.id
        let latitude = venue.latitude
        let longitude = venue.longitude
        Task {
            let candidate = await namer.candidates(latitude: latitude, longitude: longitude, limit: 1).first
            let address = candidate == nil ? await namer.address(latitude: latitude, longitude: longitude) : nil
            let descriptor = FetchDescriptor<Venue>(predicate: #Predicate { $0.id == venueID })
            guard let venue = try? context.fetch(descriptor).first, venue.nameSource != .user else { return }
            if let candidate {
                venue.name = candidate.name
                venue.nameSource = .auto
            } else if let address {
                venue.name = address
                venue.nameSource = .address
            } else {
                return
            }
            save()
        }
    }
}

extension Venue {
    var fix: LocationFix {
        LocationFix(timestamp: arrivedAt, latitude: latitude, longitude: longitude, horizontalAccuracy: 0)
    }

    func distance(toLatitude latitude: Double, longitude: Double) -> Double {
        fix.distance(to: LocationFix(timestamp: arrivedAt, latitude: latitude, longitude: longitude, horizontalAccuracy: 0))
    }
}
