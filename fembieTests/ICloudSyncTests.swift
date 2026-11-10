import Foundation
import Testing
@testable import fembie

@MainActor
struct ICloudSyncTests {
    private let directory = URL.temporaryDirectory.appending(path: "SyncTests-\(UUID())")
    private let suite = "SyncTests-\(UUID())"

    private func settings() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suite))
    }

    private func cleanup() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    private func model(_ repository: FileTrackingRepository, _ transport: TestCloudSyncTransport,
                       _ settings: UserDefaults) -> ICloudSyncViewModel {
        ICloudSyncViewModel(repository: repository, settings: settings, transport: transport,
                           checkpointURL: directory.appending(path: "checkpoint.json"))
    }

    @Test func cloudDeletionPreservesLocalDataAndAllowsFreshOptIn() async throws {
        defer { cleanup() }
        let settings = try settings()
        let repository = FileTrackingRepository(baseURL: directory)
        let lab = LabResult(id: UUID(), test: .e2, value: 150, recordedAt: .now)
        try await repository.save(lab)
        settings.set(true, forKey: "useLatestE2ResultForLevelsCalibration")
        let transport = TestCloudSyncTransport()
        let sync = model(repository, transport, settings)
        sync.setEnabled(true)
        await sync.sync()
        await sync.deleteCloudData()
        #expect(sync.deletionCompleted)
        #expect(sync.errorMessage == nil)
        #expect(!sync.enabled)
        #expect(sync.lastSynced == nil)
        #expect(await transport.snapshot.records.isEmpty)
        #expect(try await repository.labResults() == [lab])
        #expect(settings.bool(forKey: "useLatestE2ResultForLevelsCalibration"))
        let checkpoint = try JSONDecoder().decode(SyncCheckpoint.self,
            from: Data(contentsOf: directory.appending(path: "checkpoint.json")))
        #expect(checkpoint.baseline.records.isEmpty)
        #expect(checkpoint.pending == nil)
        let restarted = model(repository, transport, settings)
        #expect(!restarted.enabled)
        await restarted.sync()
        #expect(await transport.calls == 1)
        restarted.setEnabled(true)
        await restarted.sync()
        #expect(restarted.errorMessage == nil)
        #expect(try await transport.snapshot.values(LabResult.self, prefix: "lab/") == [lab])
    }

    @Test func cloudDeletionFailureKeepsDataAndCanRetryWhileDisabled() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let transport = TestCloudSyncTransport()
        var remote = SyncSnapshot()
        try remote.insert(true, key: "preference/useLatestE2ResultForLevelsCalibration")
        await transport.configure(snapshot: remote, shouldFail: true)
        let sync = model(repository, transport, try settings())
        sync.setEnabled(true)
        await sync.deleteCloudData()
        #expect(!sync.enabled)
        #expect(!sync.isDeleting)
        #expect(!sync.deletionCompleted)
        #expect(sync.errorMessage != nil)
        #expect(await transport.snapshot == remote)
        await transport.configure(snapshot: remote)
        await sync.deleteCloudData()
        #expect(sync.deletionCompleted)
        #expect(sync.errorMessage == nil)
        #expect(await transport.snapshot.records.isEmpty)
        await sync.deleteCloudData()
        #expect(sync.deletionCompleted)
        #expect(await transport.deletionCalls == 3)
    }

    @Test func cloudDeletionRejectsDifferentAccount() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let checkpoint = SyncCheckpoint(account: "original-account")
        try JSONEncoder().encode(checkpoint).write(to: directory.appending(path: "checkpoint.json"))
        let transport = TestCloudSyncTransport()
        var remote = SyncSnapshot()
        try remote.insert(true, key: "preference/useLatestE2ResultForLevelsCalibration")
        await transport.configure(snapshot: remote)
        let sync = model(repository, transport, try settings())
        await sync.deleteCloudData()
        #expect(sync.errorMessage != nil)
        #expect(!sync.deletionCompleted)
        #expect(await transport.snapshot == remote)
    }

    @Test func cloudDeletionDoesNotOverlapSync() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let transport = TestCloudSyncTransport()
        let sync = model(repository, transport, try settings())
        await transport.configure(duringExchange: {
            await sync.deleteCloudData()
        })
        sync.setEnabled(true)
        await sync.sync()
        #expect(await transport.deletionCalls == 0)
        #expect(sync.enabled)
        #expect(sync.errorMessage == nil)
    }

    @Test func disabledByDefaultAndPersistsDeviceOptIn() async throws {
        defer { cleanup() }
        let settings = try settings()
        let repository = FileTrackingRepository(baseURL: directory)
        let transport = TestCloudSyncTransport()
        let sync = model(repository, transport, settings)
        #expect(!sync.enabled)
        await sync.sync()
        #expect(await transport.calls == 0)
        sync.setEnabled(true)
        #expect(model(repository, transport, settings).enabled)
        sync.setEnabled(false)
        await sync.sync()
        #expect(await transport.calls == 0)
    }

    @Test func uploadsEveryCollectionAndPreferencesThenDownloadsDeletion() async throws {
        defer { cleanup() }
        let settings = try settings()
        let repository = FileTrackingRepository(baseURL: directory)
        var regimen = try Regimen(id: UUID(), ester: "EEn", doseMilligramsOfEster: 3,
            route: .intramuscular, intervalHours: 168, effectiveFrom: .now,
            effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let event = InjectionEvent(id: UUID(), regimenID: regimen.id, scheduledAt: regimen.effectiveFrom,
                                   doseMilligramsOfEster: 3)
        regimen.injectionEvents = [event]
        let checkIn = CheckIn(id: UUID(), recordedAt: .now, mood: 6, libido: 7, energy: 8)
        let lab = LabResult(id: UUID(), test: .e2, value: 150, recordedAt: .now)
        try await repository.save(regimen)
        try await repository.save(event)
        try await repository.save(checkIn)
        try await repository.save(lab)
        settings.set(true, forKey: "useLatestE2ResultForLevelsCalibration")
        let transport = TestCloudSyncTransport()
        let sync = model(repository, transport, settings)
        sync.setEnabled(true)
        await sync.sync()
        #expect(sync.errorMessage == nil)
        #expect(sync.lastSynced != nil)
        let uploaded = await transport.snapshot
        #expect(uploaded.records.count == 5)
        #expect(uploaded.records["preference/iCloudSyncEnabled"] == nil)
        #expect(try uploaded.values(LabResult.self, prefix: "lab/") == [lab])
        #expect(try uploaded.values(Regimen.self, prefix: "regimen/").first?.injectionEvents.first?.id == event.id)

        var remote = uploaded
        remote.records["lab/\(lab.id)"] = nil
        remote.records["checkIn/\(checkIn.id)"] = nil
        try remote.insert(false, key: "preference/useLatestE2ResultForLevelsCalibration")
        await transport.configure(snapshot: remote)
        // Recreate the model to exercise the durable baseline.
        let restarted = model(repository, transport, settings)
        await restarted.sync()
        #expect(restarted.errorMessage == nil)
        #expect(try await repository.labResults().isEmpty)
        #expect(try await repository.checkIns().isEmpty)
        #expect(!settings.bool(forKey: "useLatestE2ResultForLevelsCalibration"))
        #expect(try await FileTrackingRepository(baseURL: directory).labResults().isEmpty)
    }

    @Test func offlineFailureKeepsLocalDataAndRetries() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let lab = LabResult(id: UUID(), test: .e2, value: 150, recordedAt: .now)
        try await repository.save(lab)
        let transport = TestCloudSyncTransport()
        await transport.configure(shouldFail: true)
        let sync = model(repository, transport, try settings())
        sync.setEnabled(true)
        await sync.sync()
        #expect(sync.errorMessage != nil)
        #expect(try await repository.labResults() == [lab])
        await transport.configure()
        await sync.sync()
        #expect(sync.errorMessage == nil)
        #expect(try await transport.snapshot.values(LabResult.self, prefix: "lab/") == [lab])
    }

    @Test func editsDuringNetworkRequestArePreservedAndUploadedNextTime() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let original = LabResult(id: UUID(), test: .e2, value: 150, recordedAt: .now)
        let edited = LabResult(id: original.id, test: .e2, value: 175, recordedAt: original.recordedAt)
        try await repository.save(original)
        let transport = TestCloudSyncTransport()
        await transport.configure(duringExchange: { try await repository.save(edited) })
        let sync = model(repository, transport, try settings())
        sync.setEnabled(true)
        await sync.sync()
        #expect(try await repository.labResults() == [edited])
        await sync.sync()
        #expect(try await transport.snapshot.values(LabResult.self, prefix: "lab/") == [edited])
    }

    @Test func disablingDuringRequestDoesNotApplyIncomingData() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let transport = TestCloudSyncTransport()
        let sync = model(repository, transport, try settings())
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: .now)
        var remote = SyncSnapshot()
        try remote.insert(lab, key: "lab/\(lab.id)")
        await transport.configure(snapshot: remote, duringExchange: {
            await sync.setEnabled(false)
        })
        sync.setEnabled(true)
        await sync.sync()
        #expect(!sync.enabled)
        #expect(sync.lastSynced == nil)
        #expect(try await repository.labResults().isEmpty)
    }

    @Test func invalidRemoteDataDoesNotReplaceLocalData() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: .now)
        try await repository.save(lab)
        let transport = TestCloudSyncTransport()
        await transport.configure(snapshot: SyncSnapshot(records: ["lab/bad": Data()]))
        let sync = model(repository, transport, try settings())
        sync.setEnabled(true)
        await sync.sync()
        #expect(sync.errorMessage != nil)
        #expect(try await repository.labResults() == [lab])
    }

    @Test func recoveryJournalFinishesInterruptedApplyBeforeNextExchange() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: .now)
        var pending = SyncSnapshot()
        try pending.insert(lab, key: "lab/\(lab.id)")
        let checkpoint = SyncCheckpoint(account: "test-account", pending: pending, captured: .init())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint).write(to: directory.appending(path: "checkpoint.json"))
        let transport = TestCloudSyncTransport()
        await transport.configure(snapshot: pending)
        let sync = model(repository, transport, try settings())
        sync.setEnabled(true)
        await sync.sync()
        #expect(sync.errorMessage == nil)
        #expect(try await repository.labResults() == [lab])
        let saved = try JSONDecoder().decode(SyncCheckpoint.self,
            from: Data(contentsOf: directory.appending(path: "checkpoint.json")))
        #expect(saved.pending == nil)
        #expect(saved.baseline == pending)
    }

    @Test func differentAccountDoesNotUploadOrOverwriteLocalData() async throws {
        defer { cleanup() }
        let repository = FileTrackingRepository(baseURL: directory)
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: .now)
        try await repository.save(lab)
        let checkpoint = SyncCheckpoint(account: "original-account")
        try JSONEncoder().encode(checkpoint).write(to: directory.appending(path: "checkpoint.json"))
        let transport = TestCloudSyncTransport()
        let sync = model(repository, transport, try settings())
        sync.setEnabled(true)
        await sync.sync()
        #expect(sync.errorMessage != nil)
        #expect(await transport.snapshot.records.isEmpty)
        #expect(try await repository.labResults() == [lab])
    }
}
