import Foundation
import UserNotifications

@MainActor
final class LevelNotificationScheduler: LevelNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
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
        try await NotificationSchedulingCoordinator.shared.run { try await self.reconcile(events: events) }
    }

    private func reconcile(events: [LevelNotificationEvent]) async throws -> Int {
        let pending = await center.pendingNotificationRequests()
        let snapshots = pending.map {
            PendingNotificationSnapshot(
                identifier: $0.identifier,
                timestamp: ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                body: $0.content.body
            )
        }
        let plan = NotificationQueuePlanner.levels(events: events, pending: snapshots, now: Date())
        center.removePendingNotificationRequests(withIdentifiers: Array(plan.identifiersToRemove))
        do {
            for event in plan.eventsToAdd {
                // Check again because scheduling a large batch can take time.
                guard event.timestamp > Date() else { continue }
                try await center.add(Self.request(for: event))
            }
        } catch {
            let cleanup = NotificationQueuePlanner.failureCleanupIdentifiers(
                pending: snapshots,
                desired: plan.desired,
                ownedPrefix: LevelNotificationEvent.identifierPrefix
            )
            center.removePendingNotificationRequests(withIdentifiers: Array(cleanup))
            throw error
        }
        return plan.desired.count
    }

    /// Keep the earliest alerts, reserving at least one slot for the daily check-in reminder.
    nonisolated static func upcomingEvents(_ events: [LevelNotificationEvent], otherPendingCount: Int,
                               now: Date) -> [LevelNotificationEvent] {
        let upcoming = events.filter { $0.timestamp > now }.sorted {
            if $0.timestamp == $1.timestamp { return $0.id < $1.id }
            return $0.timestamp < $1.timestamp
        }
        return Array(upcoming.prefix(max(0, 64 - max(1, otherPendingCount))))
    }

    nonisolated static func request(for event: LevelNotificationEvent) -> UNNotificationRequest {
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
}
