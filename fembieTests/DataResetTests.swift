import Foundation
import Testing
@testable import fembie

@MainActor
struct DataResetTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen() throws -> Regimen {
        let draft = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 168,
            effectiveFrom: now, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        return try InjectionSchedule().extending(draft, through: now.addingTimeInterval(14 * 86400))
    }

    @Test func regimenResetClearsBothStoresAndFormButPreservesOtherData() async throws {
        let directory = URL.temporaryDirectory.appending(path: "DataResetTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let saved = try regimen()
        let checkIn = CheckIn(id: UUID(), recordedAt: now, mood: 3, libido: 4, energy: 5)
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: now)
        try await repository.save(saved)
        try await repository.save(try #require(saved.injectionEvents.first))
        try await repository.save(checkIn)
        try await repository.save(lab)
        let currentTime = now
        let model = RegimenViewModel(repository: repository, clock: { currentTime })
        await model.load()
        model.dose = "4"
        model.interval = "7"
        model.showMorePast()
        try await model.resetData()
        #expect(model.savedRegimen == nil)
        #expect(model.visibleEvents.isEmpty)
        #expect(model.dose.isEmpty)
        #expect(model.interval.isEmpty)
        #expect(model.firstInjection == now)
        #expect(model.pastCount == 2)
        #expect(model.hasLoaded)
        #expect(!model.isBusy)
        #expect(try await repository.regimens().isEmpty)
        #expect(try await repository.injectionEvents().isEmpty)
        let reloaded = FileTrackingRepository(baseURL: directory)
        #expect(try await reloaded.regimens().isEmpty)
        #expect(try await reloaded.injectionEvents().isEmpty)
        #expect(try await reloaded.checkIns().map(\.id) == [checkIn.id])
        #expect(try await reloaded.labResults() == [lab])
        await model.load()
        #expect(model.savedRegimen == nil)
    }

    @Test func wellbeingResetClearsHistoryAndSaveConfirmationButPreservesOtherData() async throws {
        let directory = URL.temporaryDirectory.appending(path: "DataResetTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let saved = try regimen()
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: now)
        try await repository.save(saved)
        try await repository.save(lab)
        let model = CheckInViewModel(repository: repository)
        await model.saveCheckIn(date: now, mood: 3, libido: 4, energy: 5)
        #expect(model.lastSavedCheckInDate != nil)
        try await model.resetData()
        #expect(model.checkIns.isEmpty)
        #expect(model.dailyAverages().isEmpty)
        #expect(model.lastSavedCheckInDate == nil)
        #expect(model.saveError == nil)
        #expect(model.historyError == nil)
        #expect(!model.isBusy)
        #expect(try await repository.checkIns().isEmpty)
        let reloaded = FileTrackingRepository(baseURL: directory)
        #expect(try await reloaded.checkIns().isEmpty)
        #expect(try await reloaded.regimens().map(\.id) == [saved.id])
        #expect(try await reloaded.labResults() == [lab])
        await model.saveCheckIn(date: now, mood: 8, libido: 9, energy: 10)
        #expect(model.checkIns.count == 1)
    }

    @Test func failedResetsKeepDisplayedDataAndReleaseBusyState() async throws {
        let directory = URL.temporaryDirectory.appending(path: "DataResetTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let saved = try regimen()
        try await repository.save(saved)
        let currentTime = now
        let regimenModel = RegimenViewModel(repository: repository, clock: { currentTime })
        await regimenModel.load()
        let wellbeingModel = CheckInViewModel(repository: repository)
        await wellbeingModel.saveCheckIn(date: now, mood: 3, libido: 4, energy: 5)
        let checkInIDs = wellbeingModel.checkIns.map(\.id)
        // Directories in place of writable files make each reset fail deterministically.
        for filename in ["injectionEvents.json", "checkIns.json"] {
            let file = directory.appending(path: filename)
            if FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.removeItem(at: file)
            }
            try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        }
        await #expect(throws: (any Error).self) { try await regimenModel.resetData() }
        await #expect(throws: (any Error).self) { try await wellbeingModel.resetData() }
        #expect(regimenModel.savedRegimen?.id == saved.id)
        #expect(wellbeingModel.checkIns.map(\.id) == checkInIDs)
        #expect(wellbeingModel.lastSavedCheckInDate == now)
        #expect(!regimenModel.isBusy)
        #expect(!wellbeingModel.isBusy)
    }

    @Test func resetsCanRecoverCorruptStoresWithoutLoadingThem() async throws {
        let directory = URL.temporaryDirectory.appending(path: "DataResetTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for filename in ["regimens.json", "injectionEvents.json", "checkIns.json"] {
            try Data("invalid JSON".utf8).write(to: directory.appending(path: filename))
        }
        let repository = FileTrackingRepository(baseURL: directory)
        try await repository.resetRegimenData()
        try await repository.resetWellbeingData()
        #expect(try await repository.regimens().isEmpty)
        #expect(try await repository.injectionEvents().isEmpty)
        #expect(try await repository.checkIns().isEmpty)
    }
}
