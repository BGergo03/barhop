import Foundation
import SwiftData

/// Trail recording and entry locations (SPEC §6).
extension NightEngine {
    /// Trail points are batched; entries and venues are saved immediately (SPEC §4).
    private static let trailSaveInterval: TimeInterval = 30
    private static let entryFixTimeout: Duration = .seconds(5)

    /// Recovery on launch and foreground (SPEC §5), including a background relaunch by
    /// Core Location: closes an ignored night, otherwise restarts tracking in a new segment.
    func resumeTrackingIfNeeded() {
        // Also restarts the Live Activity if it is gone (~8 h limit, or a background start failed).
        runMaintenance()
        guard let night = activeNight else { return }
        // Repairs the reminder too, e.g. after the auto-close setting changed.
        scheduleStillOutReminder(for: night)
        guard trackedNight == nil else { return }
        startTracking(night, startNewSegment: true)
    }

    /// Persists batched trail points, e.g. when the app moves to the background.
    func flush() {
        save()
    }

    func startTracking(_ night: Night, startNewSegment: Bool) {
        let lastPoint = night.trailPoints.max { $0.timestamp < $1.timestamp }.map {
            TrailFilter.AcceptedPoint(fix: $0.fix, segment: $0.segment)
        }
        trailFilter = TrailFilter(notBefore: night.startedAt, resumingFrom: lastPoint, startNewSegment: startNewSegment)
        stopDetector = StopDetector()
        if let openVenue = night.currentVenue {
            _ = stopDetector.anchor(at: openVenue.fix)
        }
        trackedNight = night
        location.startUpdates { [weak self] update in
            self?.handle(update)
        }
    }

    func stopTracking() {
        location.stopUpdates()
        trackedNight = nil
    }

    private func handle(_ update: LocationUpdate) {
        runMaintenance()
        guard let night = trackedNight else { return }
        let accepted = trailFilter.process(update)
        guard !accepted.isEmpty else { return }
        for point in accepted {
            let trailPoint = TrailPoint(
                timestamp: point.fix.timestamp,
                latitude: point.fix.latitude,
                longitude: point.fix.longitude,
                horizontalAccuracy: point.fix.horizontalAccuracy,
                segment: point.segment
            )
            context.insert(trailPoint)
            trailPoint.night = night
            handleStopEvents(stopDetector.process(point.fix), in: night)
        }
        if Date.now.timeIntervalSince(lastTrailSave) >= Self.trailSaveInterval {
            save()
        }
    }

    /// Takes a fresh fix for a just-logged entry (falling back to the latest trail point),
    /// then attaches the entry to the venue it was logged in.
    func attachLocation(toEntryWithID entryID: UUID) async {
        let freshFix = await location.currentFix(timeout: Self.entryFixTimeout)
        // Re-fetch: the entry may have been deleted or undone while waiting for the fix,
        // and touching a deleted model traps.
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == entryID })
        guard let entry = try? context.fetch(descriptor).first, let night = entry.night else { return }
        let latestTrailFix = night.trailPoints.max { $0.timestamp < $1.timestamp }?.fix
        guard let fix = freshFix ?? latestTrailFix else {
            entry.venue = night.currentVenue
            save()
            return
        }
        entry.latitude = fix.latitude
        entry.longitude = fix.longitude
        entry.horizontalAccuracy = fix.horizontalAccuracy
        assignVenue(to: entry, at: fix, in: night)
        save()
    }
}

extension TrailPoint {
    var fix: LocationFix {
        LocationFix(timestamp: timestamp, latitude: latitude, longitude: longitude, horizontalAccuracy: horizontalAccuracy)
    }
}
