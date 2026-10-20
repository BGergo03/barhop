import Foundation

/// When a quiet night gets the "Still out?" reminder and when it is closed for good (SPEC §5).
struct AutoClose: Equatable {
    /// Quiet time before the reminder.
    var interval: TimeInterval
    /// Extra time after the reminder before an ignored night is closed.
    var grace: TimeInterval

    static let defaultGrace: TimeInterval = 30 * 60

    func reminderDate(lastActivityAt: Date) -> Date {
        lastActivityAt.addingTimeInterval(interval)
    }

    /// True once `now` is strictly past the reminder plus the grace period.
    func shouldClose(lastActivityAt: Date, now: Date) -> Bool {
        now > reminderDate(lastActivityAt: lastActivityAt).addingTimeInterval(grace)
    }

    /// The policy from Settings. In debug builds "hours as minutes" scales the whole
    /// policy down 60× (hours become minutes, the 30 min grace becomes 30 s) for testing.
    static func current(defaults: UserDefaults = .standard) -> AutoClose {
        let hours = defaults.object(forKey: AppSettings.autoCloseHoursKey) as? Int ?? AppSettings.defaultAutoCloseHours
        var unit: TimeInterval = 60 * 60
        #if DEBUG
        if defaults.bool(forKey: AppSettings.autoCloseDebugMinutesKey) { unit = 60 }
        #endif
        return AutoClose(interval: TimeInterval(hours) * unit, grace: defaultGrace * unit / 3600)
    }
}
