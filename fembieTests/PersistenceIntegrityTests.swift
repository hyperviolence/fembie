import Foundation
import Testing
@testable import fembie

struct PersistenceIntegrityTests {
    private func directory() -> URL {
        URL.temporaryDirectory.appending(path: "PersistenceIntegrityTests-\(UUID())", directoryHint: .isDirectory)
    }

    private func regimen(id: UUID = UUID()) throws -> Regimen {
        try Regimen(id: id, ester: "Estradiol Enanthate (EEn)", doseMilligramsOfEster: 2,
                    route: .intramuscular, intervalHours: 24,
                    effectiveFrom: Date(timeIntervalSince1970: 1_700_000_000),
                    effectiveUntil: nil, timeZoneIdentifier: "UTC")
    }

    @Test func checkInValidationCoversEveryBoundaryAndNonFiniteValue() throws {
        let validDate = Date(timeIntervalSince1970: 1_700_000_000)
        for value in [0.0, 10.0] {
            try CheckIn(id: UUID(), recordedAt: validDate, mood: value, libido: value, energy: value).validate()
        }
        for value in [-0.001, 10.001, .nan, .infinity, -.infinity] {
            #expect(throws: TrackingValidationError.self) {
                try CheckIn(id: UUID(), recordedAt: validDate, mood: value, libido: 5, energy: 5).validate()
            }
            #expect(throws: TrackingValidationError.self) {
                try CheckIn(id: UUID(), recordedAt: validDate, mood: 5, libido: value, energy: 5).validate()
            }
            #expect(throws: TrackingValidationError.self) {
                try CheckIn(id: UUID(), recordedAt: validDate, mood: 5, libido: 5, energy: value).validate()
            }
        }
        #expect(throws: TrackingValidationError.self) {
            try CheckIn(id: UUID(), recordedAt: Date(timeIntervalSinceReferenceDate: .nan),
                        mood: 5, libido: 5, energy: 5).validate()
        }
    }

    @Test func checkInStoreUpsertsByIDAndPreservesDistinctIdenticalRecords() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let id = UUID()
        let date = Date(timeIntervalSince1970: 100)
        try await repository.save(CheckIn(id: id, recordedAt: date, mood: 1, libido: 2, energy: 3))
        try await repository.save(CheckIn(id: id, recordedAt: date, mood: 4, libido: 5, energy: 6))
        try await repository.save(CheckIn(id: UUID(), recordedAt: date, mood: 4, libido: 5, energy: 6))

        let values = try await FileTrackingRepository(baseURL: url).checkIns()
        #expect(values.count == 2)
        #expect(values.first { $0.id == id }?.mood == 4)
    }

    @Test func failedCheckInWriteDoesNotCommitCache() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let first = CheckIn(id: UUID(), recordedAt: .now, mood: 5, libido: 5, energy: 5)
        try await repository.save(first)
        let file = url.appending(path: "checkIns.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)

        await #expect(throws: (any Error).self) {
            try await repository.save(CheckIn(id: UUID(), recordedAt: .now, mood: 6, libido: 6, energy: 6))
        }
        #expect(try await repository.checkIns().map(\.id) == [first.id])
    }

    @Test func injectionEventStoreInsertsUpdatesRestartsAndPreservesFractionalDates() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let id = UUID()
        let regimenID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let first = InjectionEvent(id: id, regimenID: regimenID, scheduledAt: date, doseMilligramsOfEster: 2)
        try await repository.save(first)
        let updated = InjectionEvent(id: id, regimenID: regimenID, scheduledAt: date,
                                     doseMilligramsOfEster: 3, adjustment: .skipped)
        let identical = InjectionEvent(id: UUID(), regimenID: regimenID, scheduledAt: date,
                                       doseMilligramsOfEster: 3, adjustment: .skipped)
        try await repository.save(updated)
        try await repository.save(identical)

        let values = try await FileTrackingRepository(baseURL: url).injectionEvents()
        #expect(values.count == 2)
        #expect(values.first { $0.id == id }?.scheduledAt == date)
        #expect(values.first { $0.id == id }?.adjustment == .skipped)
    }

    @Test func injectionEventStoreRejectsInvalidValuesAndPreservesCacheAfterWriteFailure() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let valid = InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: .now, doseMilligramsOfEster: 2)
        try await repository.save(valid)
        for invalid in [
            InjectionEvent(id: UUID(), regimenID: UUID(),
                           scheduledAt: Date(timeIntervalSinceReferenceDate: .nan), doseMilligramsOfEster: 2),
            InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: .now, doseMilligramsOfEster: 0),
            InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: .now, doseMilligramsOfEster: .infinity),
            InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: .now, doseMilligramsOfEster: 2,
                           adjustment: .moved(actualAt: Date(timeIntervalSinceReferenceDate: .nan)))
        ] {
            await #expect(throws: RegimenValidationError.self) { try await repository.save(invalid) }
        }

        let file = url.appending(path: "injectionEvents.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        await #expect(throws: (any Error).self) {
            try await repository.save(InjectionEvent(id: UUID(), regimenID: UUID(),
                                                     scheduledAt: .now, doseMilligramsOfEster: 2))
        }
        #expect(try await repository.injectionEvents().map(\.id) == [valid.id])
    }

    @Test func corruptInjectionEventStoreThrowsWithoutAffectingOtherStores() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url.appending(path: "injectionEvents.json"))
        let repository = FileTrackingRepository(baseURL: url)
        await #expect(throws: (any Error).self) { try await repository.injectionEvents() }
        #expect(try await repository.regimens().isEmpty)
        #expect(try await repository.checkIns().isEmpty)
    }

    @Test func regimenRejectsDuplicateAndForeignEventIdentifiersBeforePersistence() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let original = try regimen()
        try await repository.save(original)

        var duplicate = try regimen()
        let sharedID = UUID()
        duplicate.injectionEvents = [
            InjectionEvent(id: sharedID, regimenID: duplicate.id, scheduledAt: duplicate.effectiveFrom,
                           doseMilligramsOfEster: 2),
            InjectionEvent(id: sharedID, regimenID: duplicate.id,
                           scheduledAt: duplicate.effectiveFrom.addingTimeInterval(86_400),
                           doseMilligramsOfEster: 2)
        ]
        await #expect(throws: RegimenValidationError.self) { try await repository.save(duplicate) }

        var foreign = try regimen()
        foreign.injectionEvents = [
            InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: foreign.effectiveFrom,
                           doseMilligramsOfEster: 2)
        ]
        await #expect(throws: RegimenValidationError.self) { try await repository.save(foreign) }
        #expect(try await repository.regimens().first?.id == original.id)
    }

    @Test func independentlyGeneratedEventIdentifiersPersistNormally() async throws {
        var value = try regimen()
        value = try InjectionSchedule().extending(value, through: value.effectiveFrom.addingTimeInterval(5 * 86_400))
        #expect(Set(value.injectionEvents.map(\.id)).count == value.injectionEvents.count)
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        try await repository.save(value)
        #expect(try await repository.regimens().first?.injectionEvents.count == 6)
    }

    @Test func failedSecondResetWriteRestoresFirstStoreAndCaches() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let value = try regimen()
        let event = InjectionEvent(id: UUID(), regimenID: value.id,
                                   scheduledAt: value.effectiveFrom, doseMilligramsOfEster: 2)
        try await repository.save(value)
        try await repository.save(event)
        let regimenFile = url.appending(path: "regimens.json")
        try FileManager.default.removeItem(at: regimenFile)
        try FileManager.default.createDirectory(at: regimenFile, withIntermediateDirectories: true)

        await #expect(throws: (any Error).self) { try await repository.resetRegimenData() }
        #expect(try await repository.regimens().first?.id == value.id)
        #expect(try await repository.injectionEvents().map(\.id) == [event.id])
        #expect(try await FileTrackingRepository(baseURL: url).injectionEvents().map(\.id) == [event.id])
    }
}
