import Foundation
import Observation

@MainActor
@Observable
final class CheckInReminderViewModel {
    var preferences: CheckInReminderPreferences {
        didSet {
            message = nil
            if let data = try? JSONEncoder().encode(preferences) {
                settings.set(data, forKey: Self.settingsKey)
            }
        }
    }
    private(set) var message: String?
    @ObservationIgnored private let settings: UserDefaults
    @ObservationIgnored private let scheduler: any CheckInReminderScheduling
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    private static let settingsKey = "checkInReminderPreferences"

    init(settings: UserDefaults = .standard,
         scheduler: any CheckInReminderScheduling = CheckInReminderScheduler()) {
        self.settings = settings
        self.scheduler = scheduler
        if let data = settings.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(CheckInReminderPreferences.self, from: data),
           (0...23).contains(saved.hour), (0...59).contains(saved.minute) {
            preferences = saved
        } else {
            preferences = CheckInReminderPreferences()
        }
    }

    var time: Date {
        get {
            Calendar.current.date(bySettingHour: preferences.hour, minute: preferences.minute,
                                  second: 0, of: .now) ?? .now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.hour = components.hour ?? 20
            preferences.minute = components.minute ?? 0
        }
    }

    func refresh() async {
        let selected = preferences
        let previous = updateTask
        // Finish older operations before applying the latest time or cancellation.
        let task = Task { @MainActor in
            await previous?.value
            guard preferences == selected else { return }
            await reconcile(selected)
        }
        updateTask = task
        await task.value
    }

    private func reconcile(_ selected: CheckInReminderPreferences) async {
        guard selected.enabled else {
            await scheduler.cancel()
            return
        }
        do {
            let allowed = try await scheduler.requestAuthorization()
            guard preferences == selected else { return }
            guard allowed else {
                preferences.enabled = false
                message = "Notifications are disabled in iOS. Allow notifications for fembie in Settings, then turn this on again."
                await scheduler.cancel()
                return
            }
            try await scheduler.schedule(hour: selected.hour, minute: selected.minute)
            if preferences == selected { message = nil }
        } catch {
            await scheduler.cancel()
            guard preferences == selected else { return }
            message = "Could not schedule the check-in reminder: \(error.localizedDescription)"
        }
    }
}
