import Foundation
import Observation

@MainActor
@Observable
final class ICloudSyncViewModel {
    private(set) var enabled: Bool
    private(set) var isSyncing = false
    private(set) var isDeleting = false
    private(set) var deletionCompleted = false
    private(set) var lastSynced: Date?
    private(set) var errorMessage: String?
    private(set) var revision = 0

    @ObservationIgnored private let repository: FileTrackingRepository
    @ObservationIgnored private let transport: any CloudSyncTransport
    @ObservationIgnored private let settings: UserDefaults
    @ObservationIgnored private let checkpointURL: URL
    @ObservationIgnored private var generation = 0

    static let preferenceKeys = [
        "levelsNotificationPreferences", "regimenNotificationPreferences",
        "checkInReminderPreferences", "useLatestE2ResultForLevelsCalibration"
    ]

    init(repository: FileTrackingRepository, settings: UserDefaults = .standard,
         transport: any CloudSyncTransport = CloudKitSyncTransport(), checkpointURL: URL? = nil) {
        self.repository = repository
        self.settings = settings
        self.transport = transport
        self.checkpointURL = checkpointURL ?? URL.applicationSupportDirectory.appending(path: "iCloudSync/checkpoint.json")
        enabled = settings.bool(forKey: "iCloudSyncEnabled")
    }

    func setEnabled(_ value: Bool) {
        guard !isDeleting else { return }
        deletionCompleted = false
        generation += 1
        enabled = value
        settings.set(value, forKey: "iCloudSyncEnabled")
        errorMessage = nil
    }

    func deleteCloudData() async {
        guard !isSyncing, !isDeleting else { return }
        setEnabled(false)
        isDeleting = true
        defer { isDeleting = false }
        do {
            let checkpoint = try readCheckpoint()
            try await transport.deleteData(account: checkpoint.account)
            // Discard the baseline and any pending incoming data before a future opt-in.
            try writeCheckpoint(SyncCheckpoint())
            lastSynced = nil
            deletionCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sync() async {
        guard enabled, !isSyncing, !isDeleting else { return }
        isSyncing = true
        let generation = generation
        defer { isSyncing = false }
        do {
            var checkpoint = try readCheckpoint()
            if let pending = checkpoint.pending, let captured = checkpoint.captured {
                try await apply(pending, captured: captured)
                checkpoint.baseline = pending
                checkpoint.pending = nil
                checkpoint.captured = nil
                try writeCheckpoint(checkpoint)
            }
            var captured = try await repository.syncSnapshot()
            try capturePreferences(into: &captured)
            try captured.validate()
            guard enabled, self.generation == generation else { return }
            let (merged, account) = try await transport.exchange(
                local: captured, baseline: checkpoint.baseline, account: checkpoint.account)
            guard enabled, self.generation == generation, !Task.isCancelled else { return }
            try merged.validate()
            checkpoint.account = account
            checkpoint.pending = merged
            checkpoint.captured = captured
            // Persist a recovery journal before changing local files or preferences.
            try writeCheckpoint(checkpoint)
            try await apply(merged, captured: captured)
            checkpoint.baseline = merged
            checkpoint.pending = nil
            checkpoint.captured = nil
            try writeCheckpoint(checkpoint)
            lastSynced = Date()
            errorMessage = nil
        } catch is CancellationError {
            // The app became inactive; retry on the next activation.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func capturePreferences(into snapshot: inout SyncSnapshot) throws {
        for key in Self.preferenceKeys {
            if key == "useLatestE2ResultForLevelsCalibration" {
                if settings.object(forKey: key) != nil {
                    try snapshot.insert(settings.bool(forKey: key), key: "preference/" + key)
                }
            } else if let data = settings.data(forKey: key) {
                snapshot.records["preference/" + key] = data
            }
        }
    }

    private func apply(_ snapshot: SyncSnapshot, captured: SyncSnapshot) async throws {
        try snapshot.validate()
        let decoder = JSONDecoder()
        let changed = try await repository.applySyncSnapshot(snapshot, captured: captured)
        var current = SyncSnapshot()
        try capturePreferences(into: &current)
        var preferencesChanged = false
        for key in Self.preferenceKeys {
            let recordKey = "preference/" + key
            // Preserve settings changed while the network request was in flight.
            guard current.records[recordKey] == captured.records[recordKey] else { continue }
            let data = snapshot.records[recordKey]
            guard current.records[recordKey] != data else { continue }
            if key == "useLatestE2ResultForLevelsCalibration", let data {
                settings.set(try decoder.decode(Bool.self, from: data), forKey: key)
            } else {
                settings.set(data, forKey: key)
            }
            preferencesChanged = true
        }
        if changed || preferencesChanged { revision += 1 }
    }

    private func readCheckpoint() throws -> SyncCheckpoint {
        do {
            return try JSONDecoder().decode(SyncCheckpoint.self, from: Data(contentsOf: checkpointURL))
        } catch CocoaError.fileReadNoSuchFile {
            return SyncCheckpoint()
        }
    }

    private func writeCheckpoint(_ checkpoint: SyncCheckpoint) throws {
        try FileManager.default.createDirectory(at: checkpointURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint).write(to: checkpointURL, options: .atomic)
    }
}
