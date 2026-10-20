import Foundation
import Observation
import SwiftData
import os

/// The single entry point for every change to night data. UI, intents and
/// notification actions all go through here; views only read via `@Query`.
@MainActor
@Observable
final class NightEngine {
    static let shared = NightEngine(context: ModelContainerFactory.shared.mainContext, location: LocationService())

    /// Trail points are batched; entries and venues are saved immediately (SPEC §4).
    private static let trailSaveInterval: TimeInterval = 30
    private static let entryFixTimeout: Duration = .seconds(5)

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored let location: LocationProviding
    @ObservationIgnored private let logger = Logger(subsystem: "com.bgergo03.barhop", category: "NightEngine")
    @ObservationIgnored private var trackedNight: Night?
    @ObservationIgnored private var trailFilter = TrailFilter()
    @ObservationIgnored private var lastTrailSave = Date.distantPast

    init(context: ModelContext, location: LocationProviding) {
        self.context = context
        self.location = location
    }

    var isLocationDenied: Bool { location.isAuthorizationDenied }

    var activeNight: Night? {
        var descriptor = FetchDescriptor<Night>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Returns the active night, starting one if none is active.
    @discardableResult
    func startNight(at date: Date = .now) -> Night {
        if let night = activeNight { return night }
        let night = Night(startedAt: date)
        context.insert(night)
        save()
        startTracking(night, startNewSegment: false)
        return night
    }

    /// Logs a beer, starting a night first if none is active.
    @discardableResult
    func logBeer(at date: Date = .now) -> Entry {
        let night = startNight(at: date)
        let entry = Entry(drink: .beer, at: date)
        context.insert(entry)
        entry.night = night
        night.lastActivityAt = date
        save()
        let entryID = entry.id
        Task { await attachLocation(toEntryWithID: entryID) }
        return entry
    }

    func deleteEntry(_ entry: Entry) {
        let night = entry.night
        context.delete(entry)
        save()
        if let night { refreshLastActivity(of: night) }
    }

    func editEntryTime(_ entry: Entry, to date: Date) {
        guard let night = entry.night else { return }
        let range = night.entryTimeRange()
        entry.timestamp = min(max(date, range.lowerBound), range.upperBound)
        refreshLastActivity(of: night)
    }

    func endNight(_ night: Night, reason: EndReason = .manual, at date: Date = .now) {
        guard night.isActive else { return }
        if trackedNight == night { stopTracking() }
        night.endedAt = date
        night.endReason = reason
        save()
    }

    func deleteNight(_ night: Night) {
        context.delete(night)
        save()
    }

    /// Restarts tracking for an active night after the app was relaunched
    /// (including a background relaunch by Core Location). The restart opens a new segment.
    func resumeTrackingIfNeeded() {
        guard trackedNight == nil, let night = activeNight else { return }
        startTracking(night, startNewSegment: true)
    }

    /// Persists batched trail points, e.g. when the app moves to the background.
    func flush() {
        save()
    }

    // MARK: - Location

    private func startTracking(_ night: Night, startNewSegment: Bool) {
        let lastPoint = night.trailPoints.max { $0.timestamp < $1.timestamp }.map {
            TrailFilter.AcceptedPoint(
                fix: LocationFix(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude, horizontalAccuracy: $0.horizontalAccuracy),
                segment: $0.segment
            )
        }
        trailFilter = TrailFilter(resumingFrom: lastPoint, startNewSegment: startNewSegment)
        trackedNight = night
        location.startUpdates { [weak self] update in
            self?.handle(update)
        }
    }

    private func stopTracking() {
        location.stopUpdates()
        trackedNight = nil
    }

    private func handle(_ update: LocationUpdate) {
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
        }
        if Date.now.timeIntervalSince(lastTrailSave) >= Self.trailSaveInterval {
            save()
        }
    }

    /// Takes a fresh fix for a just-logged entry, falling back to the latest trail point.
    private func attachLocation(toEntryWithID entryID: UUID) async {
        let fix = await location.currentFix(timeout: Self.entryFixTimeout)
        // Re-fetch: the entry may have been deleted or undone while waiting for the fix,
        // and touching a deleted model traps.
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == entryID })
        guard let entry = try? context.fetch(descriptor).first else { return }
        if let fix {
            entry.latitude = fix.latitude
            entry.longitude = fix.longitude
            entry.horizontalAccuracy = fix.horizontalAccuracy
        } else if let latest = entry.night?.trailPoints.max(by: { $0.timestamp < $1.timestamp }) {
            entry.latitude = latest.latitude
            entry.longitude = latest.longitude
            entry.horizontalAccuracy = latest.horizontalAccuracy
        } else {
            return
        }
        save()
    }

    private func refreshLastActivity(of night: Night) {
        night.lastActivityAt = night.entries.map(\.timestamp).max() ?? night.startedAt
        save()
    }

    private func save() {
        do {
            try context.save()
            lastTrailSave = .now
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
