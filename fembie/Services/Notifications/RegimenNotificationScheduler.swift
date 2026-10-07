import Foundation
import UserNotifications

@MainActor
final class RegimenNotificationScheduler: RegimenNotificationScheduling {
    private let center: UNUserNotificationCenter
    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func authorize() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return try await center.requestAuthorization(options: [.alert, .sound])
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        @unknown default: return false
        }
    }

    func replace(events: [RegimenNotificationEvent]) async throws -> Int {
        try await NotificationSchedulingCoordinator.shared.run { try await self.reconcile(events) }
    }

    private func reconcile(_ events: [RegimenNotificationEvent]) async throws -> Int {
        let pending = await center.pendingNotificationRequests()
        let owned = pending.filter { $0.identifier.hasPrefix(RegimenNotificationEvent.identifierPrefix) }
        let levels = pending.filter { $0.identifier.hasPrefix(LevelNotificationEvent.identifierPrefix) }
        let otherCount = pending.count - owned.count - levels.count
        let desired = Self.upcomingEvents(events, otherPendingCount: otherCount, now: Date())
        let desiredIDs = Set(desired.map(\.id))
        let existingIDs = Set(owned.map(\.identifier))
        // Keep room for other features, including a daily check-in reminder.
        let levelSlots = max(0, 64 - max(1, otherCount) - desired.count)
        let sortedLevels: [UNNotificationRequest] = levels.sorted { left, right in
            let leftDate = (left.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? Date.distantFuture
            let rightDate = (right.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? Date.distantFuture
            return leftDate < rightDate
        }
        let removedLevels = sortedLevels.dropFirst(levelSlots).map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers:
            Array(existingIDs.subtracting(desiredIDs)) + removedLevels)
        do {
            let existing = Dictionary(uniqueKeysWithValues: owned.map { ($0.identifier, $0) })
            for event in desired {
                guard event.timestamp > Date() else { continue }
                let request = Self.request(for: event)
                if existing[event.id]?.content.body == request.content.body { continue }
                try await center.add(request)
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: Array(existingIDs.union(desiredIDs)))
            throw error
        }
        return desired.count
    }

    static func upcomingEvents(_ events: [RegimenNotificationEvent], otherPendingCount: Int,
                               now: Date) -> [RegimenNotificationEvent] {
        let sorted = events.filter { $0.timestamp > now }.sorted {
            if $0.timestamp == $1.timestamp { return $0.id < $1.id }
            return $0.timestamp < $1.timestamp
        }
        return Array(sorted.prefix(min(32, max(0, 64 - max(1, otherPendingCount)))))
    }

    static func request(for event: RegimenNotificationEvent) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "fembie · Injection reminder"
        content.body = "You have an injection scheduled for \(event.injectionAt.formatted(date: .abbreviated, time: .shortened)). Open fembie to review your regimen."
        content.sound = .default
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.timestamp)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
    }
}
