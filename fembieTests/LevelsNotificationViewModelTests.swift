import Foundation
import Testing
import UserNotifications
@testable import fembie

@MainActor
struct LevelsNotificationViewModelTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen() throws -> Regimen {
        try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)", doseMilligramsOfEster: 4,
            route: .intramuscular, intervalHours: 7 * 24, effectiveFrom: start,
            effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
    }

    private func settings() throws -> (UserDefaults, String) {
        let name = "LevelsNotificationsTests-\(UUID())"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func disabledByDefaultAndPreferencesSurviveRelaunch() throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        #expect(!model.preferences.enabled)
        #expect(model.preferences.kinds.isEmpty)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: [.e2Peak, .rateLowest])
        let restored = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        #expect(restored.preferences == model.preferences)
        restored.preferences.enabled = false
        let disabled = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        #expect(!disabled.preferences.enabled)
        #expect(disabled.preferences.kinds == [.e2Peak, .rateLowest])
    }

    @Test func enablingSchedulesSelectedEventsAndDisablingClearsThem() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        let input = LevelsPredictionInput(regimen: try regimen())
        let now = start.addingTimeInterval(84 * 86_400)
        await model.refresh(input: input, now: now)
        #expect(scheduler.authorizationCalls == 0)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: Set(LevelNotificationKind.allCases))
        await model.refresh(input: input, now: now)
        #expect(Set(scheduler.events.map(\.kind)) == Set(LevelNotificationKind.allCases))
        #expect(scheduler.events.allSatisfy { $0.timestamp > now })
        #expect(model.scheduledCount == scheduler.events.count)
        model.preferences.kinds = [.e2Peak]
        await model.refresh(input: input, now: now)
        #expect(!scheduler.events.isEmpty)
        #expect(scheduler.events.allSatisfy { $0.kind == .e2Peak })
        model.preferences.enabled = false
        await model.refresh(input: input, now: now)
        #expect(scheduler.events.isEmpty)
        #expect(model.scheduledCount == 0)
    }

    @Test func deniedPermissionTurnsOffMasterToggleAndClearsPendingAlerts() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: [.e2Peak])
        let input = LevelsPredictionInput(regimen: try regimen())
        let now = start.addingTimeInterval(84 * 86_400)
        await model.refresh(input: input, now: now)
        #expect(!scheduler.events.isEmpty)
        scheduler.allowed = false
        await model.refresh(input: input, now: now)
        #expect(!model.preferences.enabled)
        #expect(model.preferences.kinds == [.e2Peak])
        #expect(scheduler.events.isEmpty)
        #expect(model.message?.contains("Settings") == true)
    }

    @Test func disabledOptionsAndUnsupportedRegimensRemoveOldAlerts() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: [.e2Peak])
        var regimen = try regimen()
        let now = start.addingTimeInterval(84 * 86_400)
        await model.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        #expect(!scheduler.events.isEmpty)
        model.preferences.kinds = []
        await model.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        #expect(scheduler.events.isEmpty)
        model.preferences.kinds = [.e2Peak]
        regimen.ester = "Estradiol Valerate (EV)"
        await model.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        #expect(scheduler.events.isEmpty)
        #expect(model.message?.contains("supported regimen") == true)
    }

    @Test func injectionCorrectionsReplaceEventTimesAndInvalidCalibrationFallsBack() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: Set(LevelNotificationKind.allCases))
        let now = start.addingTimeInterval(84 * 86_400)
        var input = try InjectionSchedule().extending(regimen(), through: now.addingTimeInterval(14 * 86_400))
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: now)
        let original = scheduler.events
        let next = try #require(input.injectionEvents.firstIndex { $0.scheduledAt > now })
        input.injectionEvents[next].adjustment = .skipped
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: now)
        let corrected = scheduler.events
        #expect(corrected != original)
        let futureLab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: now.addingTimeInterval(86_400))
        await model.refresh(input: LevelsPredictionInput(regimen: input, calibrationEnabled: true,
            calibrationResult: futureLab), now: now)
        #expect(scheduler.events == corrected)
    }

    @Test func lateAuthorizationCannotRestoreAlertsAfterDisabling() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        scheduler.suspendAuthorization = true
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: [.e2Peak])
        let input = LevelsPredictionInput(regimen: try regimen())
        let now = start.addingTimeInterval(84 * 86_400)
        let enabling = Task { await model.refresh(input: input, now: now) }
        while scheduler.authorizationContinuation == nil { await Task.yield() }
        model.preferences.enabled = false
        await model.refresh(input: input, now: now)
        scheduler.authorizationContinuation?.resume(returning: true)
        scheduler.authorizationContinuation = nil
        await enabling.value
        #expect(scheduler.events.isEmpty)
        #expect(model.scheduledCount == 0)
        #expect(!model.preferences.enabled)
    }

    @Test func schedulingErrorsRemoveAlertsAndExplainFailure() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: [.e2Peak])
        let input = LevelsPredictionInput(regimen: try regimen())
        let now = start.addingTimeInterval(84 * 86_400)
        await model.refresh(input: input, now: now)
        scheduler.failScheduling = true
        await model.refresh(input: input, now: now)
        #expect(scheduler.events.isEmpty)
        #expect(model.scheduledCount == 0)
        #expect(model.message?.contains("Could not schedule") == true)
    }

    @Test func schedulesEventsBeyondTheChartWindowAndExtendsThemOnRefresh() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences = LevelsNotificationPreferences(enabled: true, kinds: [.e2Peak])
        let input = LevelsPredictionInput(regimen: try regimen())
        let now = start.addingTimeInterval(84 * 86_400)
        await model.refresh(input: input, now: now)
        let first = scheduler.events
        #expect(first.contains { $0.timestamp > now.addingTimeInterval(80 * 86_400) })
        let latest = try #require(first.last?.timestamp)
        let later = now.addingTimeInterval(7 * 86_400)
        await model.refresh(input: input, now: later)
        #expect(scheduler.events.allSatisfy { $0.timestamp > later })
        #expect(scheduler.events.contains { $0.timestamp > latest })
        let retainedIDs = Set(first.filter { $0.timestamp > later }.map(\.id))
        #expect(retainedIDs.isSubset(of: Set(scheduler.events.map(\.id))))
    }

    @Test func rollingQueueKeepsEarliestEventsAndReservesOtherNotificationSlots() {
        let now = start
        let events = (1...100).map { index in
            LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(Double(index) * 3_600))
        }
        let past = LevelNotificationEvent(kind: .e2Low, timestamp: now.addingTimeInterval(-3_600))
        let queue = LevelNotificationScheduler.upcomingEvents(Array(events.reversed()) + [past],
            otherPendingCount: 4, now: now)
        #expect(queue == Array(events.prefix(60)))
        let later = now.addingTimeInterval(10 * 3_600)
        let replenished = LevelNotificationScheduler.upcomingEvents(events, otherPendingCount: 4, now: later)
        #expect(replenished == Array(events.dropFirst(10).prefix(60)))
        #expect(LevelNotificationScheduler.upcomingEvents(events, otherPendingCount: 64, now: now).isEmpty)
    }

    @Test func notificationRequestHasAbsoluteUTCTriggerAndEstimatedEventContent() throws {
        let date = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 3_600).rounded())
        let event = LevelNotificationEvent(kind: .rateLowest, timestamp: date)
        let request = LevelNotificationScheduler.request(for: event)
        #expect(request.identifier == event.id)
        #expect(request.content.body == LevelNotificationKind.rateLowest.notificationBody)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents.timeZone?.secondsFromGMT() == 0)
        #expect(trigger.nextTriggerDate() == date)
    }
}
