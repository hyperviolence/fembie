import Foundation
import Testing
@testable import fembie

struct SyncSnapshotTests {
    @Test func independentChangesAndDeletionsMerge() throws {
        let baseline = SyncSnapshot(records: ["edited": Data([1]), "deleted": Data([2])])
        let local = SyncSnapshot(records: ["edited": Data([3]), "newLocal": Data([4])])
        let remote = SyncSnapshot(records: baseline.records.merging(["newRemote": Data([5])]) { _, new in new })
        let merged = try SyncSnapshot.merge(local: local, remote: remote, baseline: baseline)
        #expect(merged.records == ["edited": Data([3]), "newLocal": Data([4]), "newRemote": Data([5])])
    }

    @Test func remoteWinsConcurrentEditsAndDeletion() throws {
        let baseline = SyncSnapshot(records: ["edited": Data([1]), "deleted": Data([2])])
        let local = SyncSnapshot(records: ["edited": Data([3]), "deleted": Data([4])])
        let remote = SyncSnapshot(records: ["edited": Data([5])])
        #expect(try SyncSnapshot.merge(local: local, remote: remote, baseline: baseline) == remote)
    }

    @Test func unchangedLocalDoesNotResurrectDeletedRecords() throws {
        let baseline = SyncSnapshot(records: ["record": Data([1])])
        #expect(try SyncSnapshot.merge(local: baseline, remote: .init(), baseline: baseline).records.isEmpty)
    }

    @Test func firstSyncCombinesDevicesAndPrefersCloudDuplicates() throws {
        let local = SyncSnapshot(records: ["shared": Data([1]), "local": Data([2])])
        let remote = SyncSnapshot(records: ["shared": Data([3]), "remote": Data([4])])
        #expect(try SyncSnapshot.merge(local: local, remote: remote, baseline: .init()).records ==
            ["shared": Data([3]), "local": Data([2]), "remote": Data([4])])
    }

    @Test func rejectsFutureVersions() {
        #expect(throws: (any Error).self) {
            try SyncSnapshot.merge(local: .init(), remote: .init(version: 2), baseline: .init())
        }
    }

    @Test func validatesIdentityDomainAndUnknownFields() throws {
        let checkIn = CheckIn(id: UUID(), recordedAt: .now, mood: 5, libido: 5, energy: 5)
        var snapshot = SyncSnapshot()
        try snapshot.insert(checkIn, key: "checkIn/\(checkIn.id)")
        try snapshot.validate()
        let roundTrip = try JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(roundTrip == snapshot)
        snapshot.records["checkIn/\(UUID())"] = snapshot.records["checkIn/\(checkIn.id)"]
        #expect(throws: (any Error).self) { try snapshot.validate() }
        #expect(throws: (any Error).self) {
            try SyncSnapshot(records: ["unknown": Data()]).validate()
        }
        var invalid = SyncSnapshot()
        try invalid.insert(CheckIn(id: checkIn.id, recordedAt: .now, mood: 11, libido: 5, energy: 5),
                           key: "checkIn/\(checkIn.id)")
        #expect(throws: (any Error).self) { try invalid.validate() }
    }

    @Test func rejectsInvalidReminderTime() throws {
        var snapshot = SyncSnapshot()
        try snapshot.insert(CheckInReminderPreferences(enabled: true, hour: 24, minute: 0),
                            key: "preference/checkInReminderPreferences")
        #expect(throws: (any Error).self) { try snapshot.validate() }
    }
}
