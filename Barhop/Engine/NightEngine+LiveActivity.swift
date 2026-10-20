import Foundation

/// Live Activity mirroring and the intents behind its buttons (SPEC §8).
extension NightEngine: NightIntentHandling {
    /// How long the Live Activity shows the undo row after a beer is logged.
    static let undoOfferDuration: TimeInterval = 10
    /// Entries older than this can't be undone, even if a stale undo row is still on screen.
    static let undoWindow: TimeInterval = 60

    /// Mirrors the active night onto the Live Activity (restarting it if it is gone),
    /// or ends the activity when no night is active. Called after every save.
    func refreshLiveActivity(now: Date = .now) {
        guard let night = activeNight else {
            undoOffer = nil
            liveActivity.end()
            return
        }
        if let offer = undoOffer, offer.until <= now { undoOffer = nil }
        let state = NightActivityAttributes.ContentState(
            beerCount: night.beerCount,
            currentVenueName: night.currentVenue?.name,
            lastEntryID: undoOffer?.entryID,
            undoUntil: undoOffer?.until
        )
        liveActivity.show(state, nightID: night.id, startedAt: night.startedAt)
    }

    /// Offers undo for a just-logged entry, then clears the row after `undoOfferDuration`.
    /// The clear is best effort: the app may be suspended by then, and the `undoWindow`
    /// rule keeps a lingering Undo button safe.
    func offerUndo(for entry: Entry, now: Date = .now) {
        undoOffer = UndoOffer(entryID: entry.id, until: now.addingTimeInterval(Self.undoOfferDuration))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.undoOfferDuration))
            self?.refreshLiveActivity()
        }
    }

    /// Deletes the active night's most recently logged entry if it was logged less than
    /// `undoWindow` ago (and is `expectedID`, when given). Returns whether it deleted anything.
    @discardableResult
    func undoLastEntry(expectedID: UUID? = nil, now: Date = .now) -> Bool {
        guard let night = activeNight,
              let last = night.entries.max(by: { $0.createdAt < $1.createdAt }),
              expectedID == nil || last.id == expectedID,
              now.timeIntervalSince(last.createdAt) < Self.undoWindow
        else { return false }
        deleteEntry(last)
        return true
    }

    func logBeerFromIntent() async {
        let entry = insertBeer(at: .now)
        // Wait for the fix here rather than in a detached task: the app may be suspended
        // as soon as the intent returns.
        await attachLocation(toEntryWithID: entry.id)
    }

    func undoLastEntryFromIntent(entryID: UUID?) {
        undoLastEntry(expectedID: entryID)
    }
}

struct UndoOffer {
    var entryID: UUID
    var until: Date
}
