import Foundation
import SwiftData
import Testing
@testable import Barhop

struct AutoClosePolicyTests {
    let lastActivity = Date(timeIntervalSince1970: 1_000_000)
    let policy = AutoClose(interval: 3 * 3600, grace: 30 * 60)

    @Test func remindsAfterInterval() {
        #expect(policy.reminderDate(lastActivityAt: lastActivity) == lastActivity.addingTimeInterval(3 * 3600))
    }

    @Test func closesOnlyStrictlyAfterGrace() {
        let boundary = lastActivity.addingTimeInterval(3 * 3600 + 30 * 60)
        #expect(!policy.shouldClose(lastActivityAt: lastActivity, now: boundary.addingTimeInterval(-1)))
        #expect(!policy.shouldClose(lastActivityAt: lastActivity, now: boundary))
        #expect(policy.shouldClose(lastActivityAt: lastActivity, now: boundary.addingTimeInterval(1)))
    }

    @Test func readsHoursFromSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "AutoClosePolicyTests-\(UUID())"))
        #expect(AutoClose.current(defaults: defaults) == AutoClose(interval: 3 * 3600, grace: 30 * 60))
        defaults.set(6, forKey: AppSettings.autoCloseHoursKey)
        #expect(AutoClose.current(defaults: defaults) == AutoClose(interval: 6 * 3600, grace: 30 * 60))
    }

    @Test func debugMinutesScaleWholePolicy() throws {
        let defaults = try #require(UserDefaults(suiteName: "AutoClosePolicyTests-\(UUID())"))
        defaults.set(2, forKey: AppSettings.autoCloseHoursKey)
        defaults.set(true, forKey: AppSettings.autoCloseDebugMinutesKey)
        #expect(AutoClose.current(defaults: defaults) == AutoClose(interval: 2 * 60, grace: 30))
    }
}

@MainActor
final class PolicyBox {
    var policy = AutoClose.neverInTests
}

@MainActor
struct AutoCloseEngineTests {
    let container = TestSupport.makeContainer()
    let location = FakeLocationProvider()
    let namer = FakeVenueNamer()
    let liveActivity = FakeLiveActivity()
    let reminders = FakeReminders()
    let box = PolicyBox()
    let start = Date(timeIntervalSince1970: 1_000_000)
    let hourPolicy = AutoClose(interval: 3600, grace: 1800)

    func makeEngine() -> NightEngine {
        NightEngine(context: container.mainContext, location: location, namer: namer, liveActivity: liveActivity, reminders: reminders, autoClose: { [box] in box.policy })
    }

    @Test func startAndEntriesScheduleReminder() throws {
        box.policy = hourPolicy
        let engine = makeEngine()
        let night = engine.startNight(at: start)
        #expect(reminders.authorizationRequests == 1)
        #expect(reminders.scheduled[night.id] == start.addingTimeInterval(3600))

        engine.logBeer(at: start.addingTimeInterval(600))
        #expect(reminders.scheduled[night.id] == start.addingTimeInterval(600 + 3600))

        engine.endNight(night, at: start.addingTimeInterval(1200))
        #expect(reminders.scheduled[night.id] == nil)
    }

    @Test func stillOutRearmsFromNow() throws {
        box.policy = hourPolicy
        let engine = makeEngine()
        let night = engine.startNight(at: start)
        let now = start.addingTimeInterval(3700)
        engine.stillOut(now: now)
        #expect(night.lastActivityAt == now)
        #expect(reminders.scheduled[night.id] == now.addingTimeInterval(3600))
    }

    @Test func notificationActionsReachTheNight() throws {
        let engine = makeEngine()
        let night = engine.startNight(at: start)
        reminders.respond(.stillOut, nightID: night.id)
        #expect(night.lastActivityAt > start)

        reminders.respond(.endNight, nightID: UUID())
        #expect(night.isActive)
        reminders.respond(.endNight, nightID: night.id)
        #expect(night.endReason == .manual)
    }

    @Test func maintenanceKeepsNightWithinGrace() throws {
        box.policy = hourPolicy
        let engine = makeEngine()
        let night = engine.startNight(at: start)
        engine.runMaintenance(now: start.addingTimeInterval(3600 + 1800))
        #expect(night.isActive)
    }

    @Test func ignoredReminderEndsNightAtLastBeerAndTrimsTrail() async throws {
        let engine = makeEngine()
        let night = engine.startNight(at: start)
        location.send(testFix(0))
        let lastBeer = engine.logBeer(at: start.addingTimeInterval(1200)).timestamp
        await TestSupport.settle()
        // Walking home afterwards: away from the start, then a long stop somewhere else.
        location.send(testFix(1500, north: 300))
        for minute in 0...20 {
            location.send(testFix(1800 + TimeInterval(minute * 60), north: 600))
        }
        #expect(night.venues.contains { $0.arrivedAt > lastBeer })

        box.policy = hourPolicy
        engine.runMaintenance(now: lastBeer.addingTimeInterval(3600 + 1800 + 1))

        #expect(night.endedAt == lastBeer)
        #expect(night.endReason == .autoClosed)
        #expect(night.trailPoints.allSatisfy { $0.timestamp <= lastBeer })
        #expect(!night.trailPoints.isEmpty)
        #expect(night.venues.allSatisfy { $0.arrivedAt <= lastBeer && ($0.leftAt ?? .distantFuture) <= lastBeer })
        #expect(!location.isRunning)
        #expect(!liveActivity.isRunning)
        #expect(reminders.scheduled[night.id] == nil)
    }

    @Test func venueWithBeerIsKeptAndClosedAtEnd() async throws {
        location.fix = testFix(600)
        let engine = makeEngine()
        let night = engine.startNight(at: start)
        let lastBeer = engine.logBeer(at: start.addingTimeInterval(600)).timestamp
        await TestSupport.settle()
        let venue = try #require(night.currentVenue)

        box.policy = hourPolicy
        engine.runMaintenance(now: lastBeer.addingTimeInterval(4 * 3600))
        #expect(night.venues.map(\.id) == [venue.id])
        #expect(venue.leftAt == lastBeer)
    }

    @Test func intentAfterIgnoredNightStartsNewOne() async throws {
        box.policy = hourPolicy
        let engine = makeEngine()
        let stale = engine.startNight(at: Date.now.addingTimeInterval(-3 * 3600))
        await engine.logBeerFromIntent()
        #expect(stale.endReason == .autoClosed)
        let fresh = try #require(engine.activeNight)
        #expect(fresh.id != stale.id)
        #expect(fresh.beerCount == 1)
    }

    @Test func recoveryAfterIgnoredNightDoesNotResumeTracking() throws {
        box.policy = hourPolicy
        let night = makeEngine().startNight(at: Date.now.addingTimeInterval(-3 * 3600))
        location.stopUpdates()

        let relaunched = makeEngine()
        relaunched.resumeTrackingIfNeeded()
        #expect(night.endReason == .autoClosed)
        #expect(!location.isRunning)
        #expect(relaunched.activeNight == nil)
    }
}
