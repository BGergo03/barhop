import Foundation
import UserNotifications
import os

/// What the user chose on a "Still out?" reminder.
enum StillOutResponse {
    case stillOut
    case endNight
}

@MainActor
protocol StillOutReminding: AnyObject {
    /// Called with the user's choice and the night the reminder was for.
    var onResponse: (@MainActor (StillOutResponse, UUID) -> Void)? { get set }
    /// Asks for notification permission; only prompts the first time.
    func requestAuthorization()
    /// Schedules the night's reminder at `date`, replacing any earlier one for that night.
    func schedule(nightID: UUID, at date: Date)
    func cancel(nightID: UUID)
}

/// The local "Still out?" notification (SPEC §5). One pending request per night under a
/// fixed identifier, so rescheduling replaces it.
@MainActor
final class NotificationService: NSObject, StillOutReminding {
    nonisolated private static let categoryID = "STILL_OUT"
    private static let stillOutActionID = "STILL_OUT"
    private static let endNightActionID = "END_NIGHT"
    nonisolated private static let nightIDKey = "nightID"

    var onResponse: (@MainActor (StillOutResponse, UUID) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.bgergo03.barhop", category: "Notifications")

    override init() {
        super.init()
        // Must be set before the app finishes launching so actions that relaunch the app arrive.
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryID,
                actions: [
                    UNNotificationAction(identifier: Self.stillOutActionID, title: String(localized: "Still out")),
                    UNNotificationAction(identifier: Self.endNightActionID, title: String(localized: "End night"), options: [.destructive]),
                ],
                intentIdentifiers: []
            ),
        ])
    }

    func requestAuthorization() {
        Task { [center, logger] in
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Notification permission request failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func schedule(nightID: UUID, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Still out?")
        content.body = String(localized: "Tap to keep your night going.")
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [Self.nightIDKey: nightID.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(for: nightID), content: content, trigger: trigger)
        Task { [center, logger] in
            do {
                try await center.add(request)
            } catch {
                // Typically: permission denied. Auto-close still happens on the next app run.
                logger.info("Could not schedule reminder: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancel(nightID: UUID) {
        let identifier = Self.identifier(for: nightID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static func identifier(for nightID: UUID) -> String {
        "still-out-\(nightID.uuidString)"
    }

    private func handle(actionID: String, nightID: UUID) {
        switch actionID {
        // Tapping the notification itself means "keep my night going" too (its body says so).
        case Self.stillOutActionID, UNNotificationDefaultActionIdentifier: onResponse?(.stillOut, nightID)
        case Self.endNightActionID: onResponse?(.endNight, nightID)
        default: break
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard content.categoryIdentifier == Self.categoryID,
              let rawID = content.userInfo[Self.nightIDKey] as? String,
              let nightID = UUID(uuidString: rawID) else { return }
        let actionID = response.actionIdentifier
        await handle(actionID: actionID, nightID: nightID)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
