import Foundation

@MainActor
protocol LevelNotificationScheduling {
    func authorize() async throws -> Bool
    /// Reconciles only fembie's level alerts, preserving unrelated notifications.
    func replace(events: [LevelNotificationEvent]) async throws -> Int
}
