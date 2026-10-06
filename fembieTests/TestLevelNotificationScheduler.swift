import Foundation
@testable import fembie

@MainActor
final class TestLevelNotificationScheduler: LevelNotificationScheduling {
    var allowed = true
    var failScheduling = false
    var suspendAuthorization = false
    var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private(set) var authorizationCalls = 0
    private(set) var events: [LevelNotificationEvent] = []
    private(set) var replacements = 0

    func authorize() async throws -> Bool {
        authorizationCalls += 1
        if suspendAuthorization {
            return await withCheckedContinuation { authorizationContinuation = $0 }
        }
        return allowed
    }

    func replace(events: [LevelNotificationEvent]) async throws -> Int {
        replacements += 1
        if failScheduling, !events.isEmpty {
            throw NSError(domain: "TestLevelNotificationScheduler", code: 1)
        }
        self.events = events
        return events.count
    }
}
