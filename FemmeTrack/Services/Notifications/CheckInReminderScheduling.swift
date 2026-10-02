import Foundation

/// Future implementation uses local notifications with explicit user opt-in.
protocol CheckInReminderScheduling {
    func requestAuthorization() async throws -> Bool
    func schedule(hour: Int, minute: Int) async throws
    func cancel() async
}
