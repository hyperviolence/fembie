import Foundation

nonisolated struct PendingNotificationSnapshot: Sendable {
    let identifier: String
    let timestamp: Date?
    let body: String
}

nonisolated struct LevelNotificationPlan: Sendable {
    let desired: [LevelNotificationEvent]
    let identifiersToRemove: Set<String>
    let eventsToAdd: [LevelNotificationEvent]
}

nonisolated struct RegimenNotificationPlan: Sendable {
    let desired: [RegimenNotificationEvent]
    let identifiersToRemove: Set<String>
    let eventsToAdd: [RegimenNotificationEvent]
}

nonisolated enum NotificationQueuePlanner {
    static func failureCleanupIdentifiers<Event: Identifiable>(
        pending: [PendingNotificationSnapshot],
        desired: [Event],
        ownedPrefix: String
    ) -> Set<String> where Event.ID == String {
        let owned = pending.lazy.filter { $0.identifier.hasPrefix(ownedPrefix) }.map(\.identifier)
        return Set(owned).union(desired.map(\.id))
    }

    static func levels(events: [LevelNotificationEvent], pending: [PendingNotificationSnapshot],
                       now: Date) -> LevelNotificationPlan {
        let owned = pending.filter { $0.identifier.hasPrefix(LevelNotificationEvent.identifierPrefix) }
        let desired = LevelNotificationScheduler.upcomingEvents(
            events,
            otherPendingCount: pending.count - owned.count,
            now: now
        )
        let desiredIDs = Set(desired.map(\.id))
        let existingIDs = Set(owned.map(\.identifier))
        return LevelNotificationPlan(
            desired: desired,
            identifiersToRemove: existingIDs.subtracting(desiredIDs),
            eventsToAdd: desired.filter { !existingIDs.contains($0.id) }
        )
    }

    static func regimen(events: [RegimenNotificationEvent], pending: [PendingNotificationSnapshot],
                        now: Date) -> RegimenNotificationPlan {
        let owned = pending.filter { $0.identifier.hasPrefix(RegimenNotificationEvent.identifierPrefix) }
        let levels = pending.filter { $0.identifier.hasPrefix(LevelNotificationEvent.identifierPrefix) }
        let otherCount = pending.count - owned.count - levels.count
        let desired = RegimenNotificationScheduler.upcomingEvents(
            events,
            otherPendingCount: otherCount,
            now: now
        )
        let desiredIDs = Set(desired.map(\.id))
        let existingIDs = Set(owned.map(\.identifier))
        let levelSlots = max(0, 64 - max(1, otherCount) - desired.count)
        let excessLevelIDs = levels.sorted {
            ($0.timestamp ?? .distantFuture) < ($1.timestamp ?? .distantFuture)
        }.dropFirst(levelSlots).map(\.identifier)

        let bodies = Dictionary(uniqueKeysWithValues: owned.map { ($0.identifier, $0.body) })
        let additions = desired.filter { event in
            bodies[event.id] != RegimenNotificationScheduler.contentBody(for: event)
        }
        return RegimenNotificationPlan(
            desired: desired,
            identifiersToRemove: existingIDs.subtracting(desiredIDs).union(excessLevelIDs),
            eventsToAdd: additions
        )
    }
}
