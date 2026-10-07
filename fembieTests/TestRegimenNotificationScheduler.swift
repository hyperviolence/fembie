import Foundation
@testable import fembie

@MainActor
final class TestRegimenNotificationScheduler: RegimenNotificationScheduling {
    var allowed = true
    var failScheduling = false
    var suspendAuthorization = false
    var continuation: CheckedContinuation<Bool, Never>?
    private(set) var authorizationCalls = 0
    private(set) var events: [RegimenNotificationEvent] = []
    func authorize() async throws -> Bool {
        authorizationCalls += 1
        if suspendAuthorization { return await withCheckedContinuation { continuation = $0 } }
        return allowed
    }
    func replace(events: [RegimenNotificationEvent]) async throws -> Int {
        if failScheduling, !events.isEmpty { throw CocoaError(.fileWriteNoPermission) }
        self.events = events
        return events.count
    }
}
