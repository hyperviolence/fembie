import Foundation
@testable import fembie

@MainActor
final class TestCheckInReminderScheduler: CheckInReminderScheduling {
    var allowed = true
    var failScheduling = false
    var suspendAuthorization = false
    var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private(set) var scheduledTime: [Int]?
    private(set) var authorizationCalls = 0

    func requestAuthorization() async throws -> Bool {
        authorizationCalls += 1
        if suspendAuthorization {
            return await withCheckedContinuation { authorizationContinuation = $0 }
        }
        return allowed
    }

    func schedule(hour: Int, minute: Int) async throws {
        if failScheduling { throw NSError(domain: "ReminderTests", code: 1) }
        scheduledTime = [hour, minute]
    }

    func cancel() async { scheduledTime = nil }
}
