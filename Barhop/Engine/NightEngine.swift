import Foundation
import Observation
import SwiftData
import os

/// The single entry point for every change to night data. UI, intents and
/// notification actions all go through here; views only read via `@Query`.
@MainActor
@Observable
final class NightEngine {
    static let shared = NightEngine(
        context: ModelContainerFactory.shared.mainContext,
        location: LocationService(),
        namer: VenueNamer(),
        liveActivity: LiveActivityController(),
        reminders: NotificationService()
    )

    // Shared with the extensions in NightEngine+Tracking.swift, +Venues.swift, +Places.swift, +LiveActivity.swift and +AutoClose.swift.
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored let location: LocationProviding
    @ObservationIgnored let namer: VenueNaming
    @ObservationIgnored let liveActivity: LiveActivityControlling
    @ObservationIgnored let reminders: StillOutReminding
    @ObservationIgnored let places: PlaceStore
    @ObservationIgnored let autoClose: @MainActor () -> AutoClose
    @ObservationIgnored let logger = Logger(subsystem: "com.bgergo03.barhop", category: "NightEngine")
    @ObservationIgnored var trackedNight: Night?
    @ObservationIgnored var trailFilter = TrailFilter()
    @ObservationIgnored var stopDetector = StopDetector()
    @ObservationIgnored var lastTrailSave = Date.distantPast
    @ObservationIgnored var undoOffer: UndoOffer?
    @ObservationIgnored var isBackfillingPlaces = false

    init(
        context: ModelContext,
        location: LocationProviding,
        namer: VenueNaming,
        liveActivity: LiveActivityControlling,
        reminders: StillOutReminding,
        autoClose: @escaping @MainActor () -> AutoClose = { AutoClose.current() }
    ) {
        self.context = context
        self.location = location
        self.namer = namer
        self.liveActivity = liveActivity
        self.reminders = reminders
        self.places = PlaceStore(context: context)
        self.autoClose = autoClose
        reminders.onResponse = { [weak self] response, nightID in
            self?.handleStillOutResponse(response, nightID: nightID)
        }
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
        reminders.requestAuthorization()
        scheduleStillOutReminder(for: night)
        startTracking(night, startNewSegment: false)
        return night
    }

    /// Logs a beer, starting a night first if none is active.
    @discardableResult
    func logBeer(at date: Date = .now) -> Entry {
        let entry = insertBeer(at: date)
        let entryID = entry.id
        Task { await attachLocation(toEntryWithID: entryID) }
        return entry
    }

    /// Logs a beer without a location yet; callers attach one with `attachLocation(toEntryWithID:)`.
    func insertBeer(at date: Date) -> Entry {
        let night = startNight(at: date)
        let entry = Entry(drink: .beer, at: date)
        context.insert(entry)
        entry.night = night
        night.lastActivityAt = max(night.lastActivityAt, date)
        offerUndo(for: entry)
        save()
        scheduleStillOutReminder(for: night)
        return entry
    }

    func deleteEntry(_ entry: Entry) {
        let night = entry.night
        if undoOffer?.entryID == entry.id { undoOffer = nil }
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
        reminders.cancel(nightID: night.id)
        closeOpenVenue(of: night, at: date)
        night.endedAt = date
        night.endReason = reason
        save()
    }

    func setShowMapOnShare(_ shows: Bool, for night: Night) {
        night.showMapOnShare = shows
        save()
    }

    func deleteNight(_ night: Night) {
        context.delete(night)
        save()
    }

    private func refreshLastActivity(of night: Night) {
        night.lastActivityAt = night.entries.map(\.timestamp).max() ?? night.startedAt
        save()
        scheduleStillOutReminder(for: night)
    }

    func save() {
        do {
            try context.save()
            lastTrailSave = .now
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshLiveActivity()
    }
}
