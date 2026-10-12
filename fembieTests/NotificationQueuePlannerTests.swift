import Foundation
import Testing
@testable import fembie

@MainActor
struct NotificationQueuePlannerTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func levelPlanRemovesOnlyObsoleteOwnedRequestsAndPreservesOtherFeatures() {
        let keep = LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(100))
        let add = LevelNotificationEvent(kind: .e2Low, timestamp: now.addingTimeInterval(200))
        let obsolete = LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(300))
        let pending = [
            PendingNotificationSnapshot(identifier: keep.id, timestamp: keep.timestamp, body: "keep"),
            PendingNotificationSnapshot(identifier: obsolete.id, timestamp: obsolete.timestamp, body: "old"),
            PendingNotificationSnapshot(identifier: "fembie.checkIn.dailyReminder", timestamp: nil, body: "other"),
            PendingNotificationSnapshot(identifier: "third.party", timestamp: nil, body: "unrelated")
        ]

        let plan = NotificationQueuePlanner.levels(events: [add, keep], pending: pending, now: now)
        #expect(plan.desired.map(\.id) == [keep.id, add.id])
        #expect(plan.identifiersToRemove == [obsolete.id])
        #expect(plan.eventsToAdd.map(\.id) == [add.id])
        #expect(!plan.identifiersToRemove.contains("fembie.checkIn.dailyReminder"))
        #expect(!plan.identifiersToRemove.contains("third.party"))
    }

    @Test func levelPlanReplacesAnEventWhenItsTimestampChanges() {
        let old = LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(100))
        let changed = LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(101))
        let pending = [PendingNotificationSnapshot(identifier: old.id, timestamp: old.timestamp, body: "old")]
        let plan = NotificationQueuePlanner.levels(events: [changed], pending: pending, now: now)
        #expect(plan.identifiersToRemove == [old.id])
        #expect(plan.eventsToAdd == [changed])
    }

    @Test func regimenPlanUpdatesStaleContentAndTrimsOnlyLatestExcessLevelAlerts() {
        let injectionID = UUID()
        let event = RegimenNotificationEvent(
            injectionID: injectionID,
            injectionAt: now.addingTimeInterval(3_600),
            timestamp: now.addingTimeInterval(1_800)
        )
        let levels = (0..<40).map { index in
            PendingNotificationSnapshot(
                identifier: "\(LevelNotificationEvent.identifierPrefix)\(index)",
                timestamp: now.addingTimeInterval(Double(index)),
                body: "level"
            )
        }
        let pending = levels + [
            PendingNotificationSnapshot(identifier: event.id, timestamp: event.timestamp, body: "stale"),
            PendingNotificationSnapshot(identifier: "fembie.checkIn.dailyReminder", timestamp: nil, body: "other")
        ]

        let plan = NotificationQueuePlanner.regimen(events: [event], pending: pending, now: now)
        #expect(plan.eventsToAdd == [event])
        // One other request and one regimen request leave 62 level slots, so none are trimmed.
        #expect(plan.identifiersToRemove.isEmpty)

        let manyEvents = (0..<32).map { index in
            RegimenNotificationEvent(
                injectionID: UUID(),
                injectionAt: now.addingTimeInterval(Double(index + 2) * 3_600),
                timestamp: now.addingTimeInterval(Double(index + 1) * 3_600)
            )
        }
        let crowded = NotificationQueuePlanner.regimen(events: manyEvents, pending: pending, now: now)
        let removedLevelIDs = crowded.identifiersToRemove.filter {
            $0.hasPrefix(LevelNotificationEvent.identifierPrefix)
        }
        #expect(removedLevelIDs.count == 9)
        #expect(!crowded.identifiersToRemove.contains("fembie.checkIn.dailyReminder"))
    }

    @Test func regimenPlanRemovesOldTimestampAndAddsChangedReminder() {
        let injectionID = UUID()
        let old = RegimenNotificationEvent(injectionID: injectionID,
            injectionAt: now.addingTimeInterval(3_600), timestamp: now.addingTimeInterval(1_800))
        let changed = RegimenNotificationEvent(injectionID: injectionID,
            injectionAt: now.addingTimeInterval(7_200), timestamp: now.addingTimeInterval(5_400))
        let pending = [PendingNotificationSnapshot(
            identifier: old.id,
            timestamp: old.timestamp,
            body: RegimenNotificationScheduler.contentBody(for: old)
        )]
        let plan = NotificationQueuePlanner.regimen(events: [changed], pending: pending, now: now)
        #expect(plan.identifiersToRemove == [old.id])
        #expect(plan.eventsToAdd == [changed])
    }

    @Test func failureCleanupIncludesOwnedAndNewRequestsButNeverUnrelatedOnes() {
        let desired = [
            LevelNotificationEvent(kind: .e2Peak, timestamp: now.addingTimeInterval(100)),
            LevelNotificationEvent(kind: .e2Low, timestamp: now.addingTimeInterval(200))
        ]
        let existingOwned = "\(LevelNotificationEvent.identifierPrefix)existing"
        let cleanup = NotificationQueuePlanner.failureCleanupIdentifiers(
            pending: [
                PendingNotificationSnapshot(identifier: existingOwned, timestamp: nil, body: ""),
                PendingNotificationSnapshot(identifier: "fembie.checkIn.dailyReminder", timestamp: nil, body: ""),
                PendingNotificationSnapshot(identifier: "unrelated", timestamp: nil, body: "")
            ],
            desired: desired,
            ownedPrefix: LevelNotificationEvent.identifierPrefix
        )
        #expect(cleanup == Set([existingOwned] + desired.map(\.id)))
        #expect(!cleanup.contains("fembie.checkIn.dailyReminder"))
        #expect(!cleanup.contains("unrelated"))
    }

    @Test func coordinatorContinuesAfterFailureAndReturnsResultsToCorrectCallers() async throws {
        let coordinator = NotificationSchedulingCoordinator()
        enum Failure: Error { case expected }
        let first = Task {
            try await coordinator.run {
                throw Failure.expected
            }
        }
        let second = Task {
            try await coordinator.run { 42 }
        }
        await #expect(throws: Failure.self) { try await first.value }
        #expect(try await second.value == 42)
    }

    @Test func coordinatorKeepsThreeConcurrentOperationsFIFO() async throws {
        let coordinator = NotificationSchedulingCoordinator()
        var order: [Int] = []
        let first = Task {
            try await coordinator.run {
                order.append(1)
                try await Task.sleep(for: .milliseconds(20))
                order.append(2)
                return 10
            }
        }
        while order.isEmpty { await Task.yield() }
        let second = Task { try await coordinator.run { order.append(3); return 20 } }
        let third = Task { try await coordinator.run { order.append(4); return 30 } }
        #expect(try await first.value == 10)
        #expect(try await second.value == 20)
        #expect(try await third.value == 30)
        #expect(order == [1, 2, 3, 4])
    }

    @Test func cancellingOneCallerDoesNotBreakLaterCoordinatorUpdates() async throws {
        let coordinator = NotificationSchedulingCoordinator()
        let first = Task {
            try await coordinator.run {
                try await Task.sleep(for: .milliseconds(30))
                return 1
            }
        }
        first.cancel()
        let second = Task { try await coordinator.run { 2 } }
        _ = try? await first.value
        #expect(try await second.value == 2)
    }
}
