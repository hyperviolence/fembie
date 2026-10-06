import Foundation

@MainActor
protocol CheckInReminderScheduling {
    func requestAuthorization() async throws -> Bool
    func schedule(hour: Int, minute: Int) async throws
    func cancel() async
}
