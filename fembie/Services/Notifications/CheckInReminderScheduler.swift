import Foundation
import UserNotifications

@MainActor
final class CheckInReminderScheduler: CheckInReminderScheduling {
    nonisolated static let identifier = "fembie.checkIn.dailyReminder"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return try await center.requestAuthorization(options: [.alert, .sound])
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        @unknown default: return false
        }
    }

    func schedule(hour: Int, minute: Int) async throws {
        _ = try await NotificationSchedulingCoordinator.shared.run {
            try await self.center.add(Self.request(hour: hour, minute: minute))
            return 1
        }
    }

    func cancel() async {
        _ = try? await NotificationSchedulingCoordinator.shared.run {
            self.center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
            return 0
        }
    }

    static func request(hour: Int, minute: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "fembie · Check-in"
        content.body = "How do you feel today? Record your mood, libido, and energy in fembie."
        content.sound = .default
        // No fixed date or time zone: repeat at this local wall-clock time each day.
        let components = DateComponents(hour: hour, minute: minute)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
