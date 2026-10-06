import Foundation
import UserNotifications

@MainActor
final class LevelNotificationScheduler: NSObject, LevelNotificationScheduling, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    private var updateTask: Task<Int, any Error>?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func authorize() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return try await center.requestAuthorization(options: [.alert, .sound])
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        @unknown default: return false
        }
    }

    func replace(events: [LevelNotificationEvent]) async throws -> Int {
        // Serialize updates so a slow, older request cannot restore disabled alerts.
        let previous = updateTask
        let task = Task { @MainActor in
            _ = try? await previous?.value
            return try await reconcile(events: events)
        }
        updateTask = task
        return try await task.value
    }

    private func reconcile(events: [LevelNotificationEvent]) async throws -> Int {
        let pending = await center.pendingNotificationRequests()
        let owned = pending.filter { $0.identifier.hasPrefix(LevelNotificationEvent.identifierPrefix) }
        let otherCount = pending.count - owned.count
        let desired = Self.upcomingEvents(events, otherPendingCount: otherCount, now: Date())
        let desiredIDs = Set(desired.map(\.id))
        let existingIDs = Set(owned.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: Array(existingIDs.subtracting(desiredIDs)))
        do {
            for event in desired where !existingIDs.contains(event.id) {
                // Check again because scheduling a large batch can take time.
                guard event.timestamp > Date() else { continue }
                try await center.add(Self.request(for: event))
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: Array(existingIDs.union(desiredIDs)))
            throw error
        }
        return desired.count
    }

    /// Keep the earliest alerts and leave slots for notifications owned by other features.
    static func upcomingEvents(_ events: [LevelNotificationEvent], otherPendingCount: Int,
                               now: Date) -> [LevelNotificationEvent] {
        let upcoming = events.filter { $0.timestamp > now }.sorted {
            if $0.timestamp == $1.timestamp { return $0.id < $1.id }
            return $0.timestamp < $1.timestamp
        }
        return Array(upcoming.prefix(max(0, 64 - otherPendingCount)))
    }

    static func request(for event: LevelNotificationEvent) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "fembie · Model estimate"
        content.body = event.kind.notificationBody
        content.sound = .default
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.timestamp)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
