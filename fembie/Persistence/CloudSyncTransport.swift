import CloudKit
import Foundation

nonisolated protocol CloudSyncTransport: Sendable {
    func deleteData(account: String?) async throws
    func exchange(local: SyncSnapshot, baseline: SyncSnapshot, account: String?) async throws -> (SyncSnapshot, String)
}

/// The private database is accessed only for user-authorized sync or deletion.
actor CloudKitSyncTransport: CloudSyncTransport {
    func deleteData(account: String?) async throws {
        let container = CKContainer(identifier: "iCloud.com.hyperviolet.fembie")
        guard try await container.accountStatus() == .available else { throw SyncError.unavailable }
        let user = try await container.userRecordID().recordName
        guard account == nil || account == user else { throw SyncError.accountChanged }
        try Task.checkCancellation()
        do {
            try await container.privateCloudDatabase.deleteRecord(
                withID: CKRecord.ID(recordName: "fembie-sync-v1"))
        } catch let error as CKError where error.code == .unknownItem {
            // Already absent is a successful deletion, including retries.
        }
    }

    func exchange(local: SyncSnapshot, baseline: SyncSnapshot, account: String?) async throws -> (SyncSnapshot, String) {
        let container = CKContainer(identifier: "iCloud.com.hyperviolet.fembie")
        guard try await container.accountStatus() == .available else { throw SyncError.unavailable }
        let user = try await container.userRecordID().recordName
        guard account == nil || account == user else { throw SyncError.accountChanged }
        let database = container.privateCloudDatabase
        let id = CKRecord.ID(recordName: "fembie-sync-v1")
        // Conditional saves prevent overwriting a second device's intervening upload.
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let record: CKRecord
            do {
                record = try await database.record(for: id)
            } catch let error as CKError where error.code == .unknownItem {
                // A missing established snapshot is not an instruction to erase local data.
                guard baseline.records.isEmpty else { throw SyncError.invalidData }
                record = CKRecord(recordType: "FembieSnapshot", recordID: id)
            }
            let remote: SyncSnapshot
            if record.recordChangeTag != nil {
                guard let asset = record["snapshot"] as? CKAsset, let url = asset.fileURL else {
                    throw SyncError.invalidData
                }
                remote = try JSONDecoder().decode(SyncSnapshot.self, from: Data(contentsOf: url))
            } else {
                remote = SyncSnapshot()
            }
            try remote.validate()
            let merged = try SyncSnapshot.merge(local: local, remote: remote, baseline: baseline)
            try merged.validate()
            if merged == remote, record.recordChangeTag != nil { return (merged, user) }
            let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: url) }
            try JSONEncoder().encode(merged).write(to: url, options: .atomic)
            record["snapshot"] = CKAsset(fileURL: url)
            try Task.checkCancellation()
            guard try await container.userRecordID().recordName == user else { throw SyncError.accountChanged }
            do {
                _ = try await database.save(record)
                return (merged, user)
            } catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 {
                continue
            }
        }
        throw SyncError.unavailable
    }
}
