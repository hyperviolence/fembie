import Foundation
import Observation

@MainActor
@Observable
final class RegimenNotificationViewModel {
    var preferences: RegimenNotificationPreferences {
        didSet {
            message = nil
            if let data = try? JSONEncoder().encode(preferences) { settings.set(data, forKey: Self.settingsKey) }
        }
    }
    private(set) var message: String?
    private(set) var scheduledCount = 0
    @ObservationIgnored private let settings: UserDefaults
    @ObservationIgnored private let scheduler: any RegimenNotificationScheduling
    @ObservationIgnored private var revision = 0
    private static let settingsKey = "regimenNotificationPreferences"

    init(settings: UserDefaults = .standard,
         scheduler: any RegimenNotificationScheduling = RegimenNotificationScheduler()) {
        self.settings = settings
        self.scheduler = scheduler
        if let data = settings.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(RegimenNotificationPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = RegimenNotificationPreferences()
        }
    }

    func refresh(regimen: Regimen?, now: Date = Date()) async {
        revision += 1
        let requestRevision = revision
        let selected = preferences
        func isCurrent() -> Bool {
            revision == requestRevision && preferences == selected && !Task.isCancelled
        }
        do {
            guard selected.enabled else {
                _ = try await scheduler.replace(events: [])
                if isCurrent() { scheduledCount = 0 }
                return
            }
            message = nil
            let allowed = try await scheduler.authorize()
            guard isCurrent() else { return }
            guard allowed else {
                preferences.enabled = false
                message = "Notifications are disabled in iOS. Allow notifications for fembie in Settings, then turn this on again."
                _ = try await scheduler.replace(events: [])
                scheduledCount = 0
                return
            }
            let events = try regimen.map {
                try RegimenReminderCalculator().events(regimen: $0, leadTime: selected.leadTime, now: now)
            } ?? []
            guard isCurrent() else { return }
            let count = try await scheduler.replace(events: events)
            guard isCurrent() else { return }
            scheduledCount = count
            if regimen == nil { message = "Save a regimen to schedule dose reminders." }
            else if events.isEmpty { message = "No upcoming reminders in the next 90 days. The selected advance time may already have passed." }
            else if count < events.count { message = "The nearest \(count) reminders are scheduled. Open fembie regularly to schedule later doses." }
        } catch {
            guard isCurrent() else { return }
            _ = try? await scheduler.replace(events: [])
            guard isCurrent() else { return }
            scheduledCount = 0
            message = "Could not schedule dose reminders: \(error.localizedDescription)"
        }
    }
}
