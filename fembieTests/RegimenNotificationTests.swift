import Foundation
import Testing
import UserNotifications
@testable import fembie

@MainActor
struct RegimenNotificationTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func regimen() throws -> Regimen {
        let draft = try Regimen(id: UUID(), ester: "Estradiol Valerate (EV)", doseMilligramsOfEster: 4,
            route: .subcutaneous, intervalHours: 168, effectiveFrom: now.addingTimeInterval(4 * 3600),
            effectiveUntil: nil, timeZoneIdentifier: "UTC")
        return try InjectionSchedule().extending(draft, through: now.addingTimeInterval(90 * 86400))
    }
    private func settings() throws -> (UserDefaults, String) {
        let name = "RegimenNotificationTests-\(UUID())"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func advanceTimesTrackEffectiveInjectionTimesAndExcludeTakenSkippedAndElapsed() throws {
        let input = try regimen()
        for lead in RegimenNotificationLeadTime.allCases {
            let events = try RegimenReminderCalculator().events(regimen: input, leadTime: lead, now: now)
            #expect(events.allSatisfy { $0.timestamp == $0.injectionAt.addingTimeInterval(-Double(lead.rawValue)) })
            #expect(events.allSatisfy { $0.timestamp > now })
            #expect(events.first?.injectionID == input.injectionEvents[lead == .oneDay ? 1 : 0].id)
        }
        var changed = input
        changed.injectionEvents[0].adjustment = .confirmed
        changed.injectionEvents[1].adjustment = .skipped
        changed.injectionEvents[2].adjustment = .moved(actualAt: now.addingTimeInterval(-3600))
        let movedAt = now.addingTimeInterval(2 * 86400)
        changed.injectionEvents[3].adjustment = .moved(actualAt: movedAt)
        let events = try RegimenReminderCalculator().events(regimen: changed, leadTime: .oneHour, now: now)
        #expect(!events.contains { Set(changed.injectionEvents.prefix(3).map(\.id)).contains($0.injectionID) })
        #expect(events.first?.injectionID == changed.injectionEvents[3].id)
        #expect(events.first?.timestamp == movedAt.addingTimeInterval(-3600))
    }

    @Test func preferencesPersistAndScheduleChangesDisableAndResetReplaceReminders() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestRegimenNotificationScheduler()
        let model = RegimenNotificationViewModel(settings: settings, scheduler: scheduler)
        let input = try regimen()
        await model.refresh(regimen: input, now: now)
        #expect(!model.preferences.enabled)
        #expect(scheduler.authorizationCalls == 0)
        model.preferences = RegimenNotificationPreferences(enabled: true, leadTime: .threeHours)
        await model.refresh(regimen: input, now: now)
        let original = scheduler.events
        #expect(!original.isEmpty)
        let restored = RegimenNotificationViewModel(settings: settings, scheduler: scheduler)
        #expect(restored.preferences == model.preferences)
        model.preferences.leadTime = .oneHour
        await model.refresh(regimen: input, now: now)
        #expect(scheduler.events != original)
        var changed = input
        changed.injectionEvents[0].adjustment = .skipped
        await model.refresh(regimen: changed, now: now)
        #expect(!scheduler.events.contains { $0.injectionID == input.injectionEvents[0].id })
        await model.refresh(regimen: nil, now: now)
        #expect(scheduler.events.isEmpty)
        #expect(model.message?.contains("Save a regimen") == true)
        await model.refresh(regimen: input, now: now)
        model.preferences.enabled = false
        await model.refresh(regimen: input, now: now)
        #expect(scheduler.events.isEmpty)
        #expect(model.scheduledCount == 0)
    }

    @Test func denialAndErrorsRemoveRemindersAndExplainTheFailure() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestRegimenNotificationScheduler()
        let model = RegimenNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences.enabled = true
        await model.refresh(regimen: try regimen(), now: now)
        scheduler.allowed = false
        await model.refresh(regimen: try regimen(), now: now)
        #expect(!model.preferences.enabled)
        #expect(scheduler.events.isEmpty)
        #expect(model.message?.contains("Settings") == true)
        scheduler.allowed = true
        scheduler.failScheduling = true
        model.preferences.enabled = true
        await model.refresh(regimen: try regimen(), now: now)
        #expect(scheduler.events.isEmpty)
        #expect(model.message?.contains("Could not schedule") == true)
    }

    @Test func delayedPermissionCannotReenableDisabledReminders() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestRegimenNotificationScheduler()
        scheduler.suspendAuthorization = true
        let model = RegimenNotificationViewModel(settings: settings, scheduler: scheduler)
        model.preferences.enabled = true
        let input = try regimen()
        let enabling = Task { await model.refresh(regimen: input, now: now) }
        while scheduler.continuation == nil { await Task.yield() }
        model.preferences.enabled = false
        await model.refresh(regimen: input, now: now)
        scheduler.continuation?.resume(returning: true)
        scheduler.continuation = nil
        await enabling.value
        #expect(scheduler.events.isEmpty)
    }

    @Test func rollingWindowExtendsAndRespectsEndedRegimens() throws {
        var input = try regimen()
        let first = try RegimenReminderCalculator().events(regimen: input, leadTime: .oneHour, now: now)
        let later = try RegimenReminderCalculator().events(regimen: input, leadTime: .oneHour,
            now: now.addingTimeInterval(14 * 86400))
        #expect(later.last?.timestamp ?? .distantPast > first.last?.timestamp ?? .distantPast)
        input.effectiveUntil = input.effectiveFrom.addingTimeInterval(86400)
        let ended = try RegimenReminderCalculator().events(regimen: input, leadTime: .oneHour,
            now: now.addingTimeInterval(14 * 86400))
        #expect(ended.isEmpty)
    }

    @Test func capacityKeepsNearestRemindersAndUTCTriggerHasSelectedAdvanceTime() throws {
        let events = (1...100).map {
            RegimenNotificationEvent(injectionID: UUID(), injectionAt: now.addingTimeInterval(Double($0) * 3600),
                timestamp: now.addingTimeInterval(Double($0) * 3600 - 1800))
        }
        #expect(RegimenNotificationScheduler.upcomingEvents(Array(events.reversed()), otherPendingCount: 1,
                                                            now: now) == Array(events.prefix(32)))
        #expect(RegimenNotificationScheduler.upcomingEvents(events, otherPendingCount: 60, now: now).count == 4)
        #expect(RegimenNotificationScheduler.upcomingEvents(events, otherPendingCount: 64, now: now).isEmpty)
        let timestamp = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 3600).rounded())
        let event = RegimenNotificationEvent(injectionID: UUID(), injectionAt: timestamp.addingTimeInterval(1800),
                                             timestamp: timestamp)
        let request = RegimenNotificationScheduler.request(for: event)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents.timeZone == .gmt)
        #expect(trigger.nextTriggerDate() == timestamp)
        #expect(request.identifier.hasPrefix(RegimenNotificationEvent.identifierPrefix))
    }

    @Test func coordinatorSerializesUpdatesAcrossFeatures() async throws {
        let coordinator = NotificationSchedulingCoordinator()
        var order: [Int] = []
        let first = Task {
            try await coordinator.run {
                order.append(1)
                try await Task.sleep(for: .milliseconds(20))
                order.append(2)
                return 1
            }
        }
        while order.isEmpty { await Task.yield() }
        let second = Task { try await coordinator.run { order.append(3); return 2 } }
        _ = try await first.value
        _ = try await second.value
        #expect(order == [1, 2, 3])
    }
}
