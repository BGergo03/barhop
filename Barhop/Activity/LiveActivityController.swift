import ActivityKit
import Foundation
import os

@MainActor
protocol LiveActivityControlling: AnyObject {
    /// Shows `state` on the night's Live Activity, (re)starting it if none is running,
    /// e.g. after the system ended it at the ~8 h limit.
    func show(_ state: NightActivityAttributes.ContentState, nightID: UUID, startedAt: Date)
    /// Ends every Barhop Live Activity.
    func end()
}

@MainActor
final class LiveActivityController: LiveActivityControlling {
    private typealias NightActivity = Activity<NightActivityAttributes>

    private let logger = Logger(subsystem: "com.bgergo03.barhop", category: "LiveActivity")
    /// The last state sent to each activity, so repeated saves don't spam updates.
    private var shownStates: [NightActivity.ID: NightActivityAttributes.ContentState] = [:]
    /// Updates and ends run one after another so a newer state can't be overtaken by an older one.
    private var pendingWork: Task<Void, Never>?

    func show(_ state: NightActivityAttributes.ContentState, nightID: UUID, startedAt: Date) {
        let running = NightActivity.activities.filter { $0.activityState == .active || $0.activityState == .stale }
        if let activity = running.first(where: { $0.attributes.nightID == nightID }) {
            guard shownStates[activity.id] != state else { return }
            shownStates[activity.id] = state
            let activityID = activity.id
            enqueue { await Self.activity(withID: activityID)?.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let activity = try NightActivity.request(
                attributes: NightActivityAttributes(nightID: nightID, startedAt: startedAt),
                content: ActivityContent(state: state, staleDate: nil)
            )
            shownStates[activity.id] = state
        } catch {
            // Known limitation (SPEC §8): ActivityKit only starts activities while the app is in
            // the foreground; starting from the background needs push-to-start, which needs a paid
            // account. The next show() after the app is opened starts it. No workaround on purpose.
            logger.info("Could not start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func end() {
        for activity in NightActivity.activities {
            let activityID = activity.id
            shownStates[activityID] = nil
            enqueue { await Self.activity(withID: activityID)?.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        pendingWork = Task { [previous = pendingWork] in
            await previous?.value
            await work()
        }
    }

    /// `Activity` isn't `Sendable`, so each piece of work looks it up again off the main actor.
    nonisolated private static func activity(withID id: NightActivity.ID) -> NightActivity? {
        NightActivity.activities.first { $0.id == id }
    }
}
