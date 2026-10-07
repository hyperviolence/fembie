import Foundation

@MainActor
protocol RegimenNotificationScheduling {
    func authorize() async throws -> Bool
    func replace(events: [RegimenNotificationEvent]) async throws -> Int
}
