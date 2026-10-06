import Foundation
import Testing
import UserNotifications
@testable import fembie

@MainActor
struct CheckInReminderTests {
    private func settings() throws -> (UserDefaults, String) {
        let name = "CheckInReminderTests-\(UUID())"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func preferencesPersistAndTimePickerStoresLocalHoursAndMinutes() throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestCheckInReminderScheduler()
        let model = CheckInReminderViewModel(settings: settings, scheduler: scheduler)
        #expect(!model.preferences.enabled)
        let time = try #require(Calendar.current.date(bySettingHour: 9, minute: 35, second: 0, of: .now))
        model.time = time
        model.preferences.enabled = true
        let restored = CheckInReminderViewModel(settings: settings, scheduler: scheduler)
        #expect(restored.preferences == CheckInReminderPreferences(enabled: true, hour: 9, minute: 35))
        #expect(Calendar.current.component(.hour, from: restored.time) == 9)
        #expect(Calendar.current.component(.minute, from: restored.time) == 35)
    }

    @Test func enablingChangingTimeAndDisablingReconcileTheReminder() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestCheckInReminderScheduler()
        let model = CheckInReminderViewModel(settings: settings, scheduler: scheduler)
        await model.refresh()
        #expect(scheduler.authorizationCalls == 0)
        model.preferences.enabled = true
        await model.refresh()
        #expect(scheduler.scheduledTime == [20, 0])
        model.preferences.hour = 8
        model.preferences.minute = 15
        await model.refresh()
        #expect(scheduler.scheduledTime == [8, 15])
        model.preferences.enabled = false
        await model.refresh()
        #expect(scheduler.scheduledTime == nil)
    }

    @Test func deniedPermissionAndSchedulingFailureClearReminder() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestCheckInReminderScheduler()
        let model = CheckInReminderViewModel(settings: settings, scheduler: scheduler)
        model.preferences.enabled = true
        await model.refresh()
        scheduler.allowed = false
        await model.refresh()
        #expect(!model.preferences.enabled)
        #expect(scheduler.scheduledTime == nil)
        #expect(model.message?.contains("Settings") == true)
        scheduler.allowed = true
        scheduler.failScheduling = true
        model.preferences.enabled = true
        await model.refresh()
        #expect(scheduler.scheduledTime == nil)
        #expect(model.message?.contains("Could not schedule") == true)
    }

    @Test func disablingDuringPermissionPromptCannotRestoreReminder() async throws {
        let (settings, name) = try settings()
        defer { settings.removePersistentDomain(forName: name) }
        let scheduler = TestCheckInReminderScheduler()
        scheduler.suspendAuthorization = true
        let model = CheckInReminderViewModel(settings: settings, scheduler: scheduler)
        model.preferences.enabled = true
        let enabling = Task { await model.refresh() }
        while scheduler.authorizationContinuation == nil { await Task.yield() }
        model.preferences.enabled = false
        let disabling = Task { await model.refresh() }
        scheduler.authorizationContinuation?.resume(returning: true)
        scheduler.authorizationContinuation = nil
        await enabling.value
        await disabling.value
        #expect(scheduler.scheduledTime == nil)
        #expect(!model.preferences.enabled)
    }

    @Test func dailyTriggerUsesSelectedLocalTimeAndStableIdentifier() throws {
        let request = CheckInReminderScheduler.request(hour: 7, minute: 45)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(request.identifier == CheckInReminderScheduler.identifier)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 7)
        #expect(trigger.dateComponents.minute == 45)
        #expect(trigger.dateComponents.day == nil)
        #expect(trigger.dateComponents.timeZone == nil)
        #expect(trigger.nextTriggerDate() != nil)
        let changed = CheckInReminderScheduler.request(hour: 21, minute: 0)
        #expect(changed.identifier == request.identifier)
        let now = Date()
        let events = (1...64).map {
            LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(Double($0) * 3600))
        }
        #expect(LevelNotificationScheduler.upcomingEvents(events, otherPendingCount: 0, now: now).count == 63)
    }
}
