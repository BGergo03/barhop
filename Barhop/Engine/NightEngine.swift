import Foundation
import Observation
import SwiftData
import os

/// The single entry point for every change to night data. UI, intents and
/// notification actions all go through here; views only read via `@Query`.
@MainActor
@Observable
final class NightEngine {
    static let shared = NightEngine(context: ModelContainerFactory.shared.mainContext)

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let logger = Logger(subsystem: "com.bgergo03.barhop", category: "NightEngine")

    init(context: ModelContext) {
        self.context = context
    }

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
        night.endedAt = date
        night.endReason = reason
        save()
    }

    func deleteNight(_ night: Night) {
        context.delete(night)
        save()
    }

    private func refreshLastActivity(of night: Night) {
        night.lastActivityAt = night.entries.map(\.timestamp).max() ?? night.startedAt
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
