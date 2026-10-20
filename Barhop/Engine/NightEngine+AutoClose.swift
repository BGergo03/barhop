import Foundation
import SwiftData

/// "Still out?" reminders, auto-close and recovery (SPEC §5).
extension NightEngine {
    /// Housekeeping run on launch, on foreground, on every location update and before every
    /// intent: closes a night whose reminder was ignored, then restarts the Live Activity if
    /// it is gone (~8 h limit) or ends it if no night is active.
    func runMaintenance(now: Date = .now) {
        if let night = activeNight, autoClose().shouldClose(lastActivityAt: night.lastActivityAt, now: now) {
            autoCloseNight(night)
        }
        refreshLiveActivity(now: now)
    }

    /// Ends an ignored night at its last activity and drops what was recorded after that,
    /// e.g. the walk home with the app still tracking.
    func autoCloseNight(_ night: Night) {
        let endedAt = night.lastActivityAt
        endNight(night, reason: .autoClosed, at: endedAt)
        for point in night.trailPoints where point.timestamp > endedAt {
            context.delete(point)
        }
        for venue in night.venues {
            if venue.arrivedAt > endedAt, venue.entries.isEmpty {
                context.delete(venue)
            } else if let leftAt = venue.leftAt, leftAt > endedAt {
                venue.leftAt = max(venue.arrivedAt, endedAt)
            }
        }
        save()
        logger.info("Auto-closed night at its last activity")
    }

    /// "Still out" on the reminder: re-arms the timer from now.
    func stillOut(now: Date = .now) {
        guard let night = activeNight else { return }
        night.lastActivityAt = max(night.lastActivityAt, now)
        save()
        scheduleStillOutReminder(for: night)
    }

    /// (Re)schedules the active night's reminder, e.g. after Settings changed.
    func rescheduleStillOutReminder() {
        guard let night = activeNight else { return }
        scheduleStillOutReminder(for: night)
    }

    func scheduleStillOutReminder(for night: Night) {
        guard night.isActive else { return }
        reminders.schedule(nightID: night.id, at: autoClose().reminderDate(lastActivityAt: night.lastActivityAt))
    }

    func handleStillOutResponse(_ response: StillOutResponse, nightID: UUID) {
        // A reminder for a night that has since ended is stale; ignore it.
        guard let night = activeNight, night.id == nightID else { return }
        switch response {
        case .stillOut: stillOut()
        case .endNight: endNight(night)
        }
    }
}
