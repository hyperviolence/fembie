import Foundation
@testable import fembie

actor TestCloudSyncTransport: CloudSyncTransport {
    var snapshot = SyncSnapshot()
    var calls = 0
    var deletionCalls = 0

    var shouldFail = false
    var duringExchange: (@Sendable () async throws -> Void)?

    func configure(snapshot: SyncSnapshot = .init(), shouldFail: Bool = false,
                   duringExchange: (@Sendable () async throws -> Void)? = nil) {
        self.snapshot = snapshot
        self.shouldFail = shouldFail
        self.duringExchange = duringExchange
    }

    func deleteData(account: String?) async throws {
        deletionCalls += 1
        if shouldFail { throw SyncError.unavailable }
        guard account == nil || account == "test-account" else { throw SyncError.accountChanged }
        snapshot = SyncSnapshot()
    }

    func exchange(local: SyncSnapshot, baseline: SyncSnapshot, account: String?) async throws -> (SyncSnapshot, String) {
        calls += 1
        if shouldFail { throw SyncError.unavailable }
        guard account == nil || account == "test-account" else { throw SyncError.accountChanged }
        try await duringExchange?()
        snapshot = try SyncSnapshot.merge(local: local, remote: snapshot, baseline: baseline)
        return (snapshot, "test-account")
    }
}
