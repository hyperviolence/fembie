import Foundation
import Testing
@testable import FemmeTrack

struct FileTrackingRepositoryTests {
    private func directory() -> URL {
        URL.temporaryDirectory.appending(path: "FemmeTrackTests-\(UUID())", directoryHint: .isDirectory)
    }
    private func regimen(dose: Double) throws -> Regimen {
        try Regimen(id: UUID(), ester: "EEn", doseMilligramsOfEster: dose, intervalHours: 168,
                    effectiveFrom: Date(timeIntervalSince1970: 1_700_000_000), effectiveUntil: nil,
                    timeZoneIdentifier: "UTC")
    }

    @Test func missingStoreIsEmptyAndSaveReplacesPreviousRegimen() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        #expect(try await repository.regimens().isEmpty)
        let first = try regimen(dose: 2)
        let replacement = try regimen(dose: 3)
        try await repository.save(first)
        try await repository.save(replacement)
        let loaded = try await FileTrackingRepository(baseURL: url).regimens()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == replacement.id)
    }

    @Test func corruptStoreIsPreservedOnReadAndWrite() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appending(path: "regimens.json")
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: file)
        let repository = FileTrackingRepository(baseURL: url)
        await #expect(throws: (any Error).self) { try await repository.regimens() }
        await #expect(throws: (any Error).self) { try await repository.save(regimen(dose: 2)) }
        #expect(try Data(contentsOf: file) == corrupt)
    }

    @Test func failedWriteDoesNotCommitCache() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        let first = try regimen(dose: 2)
        try await repository.save(first)
        let file = url.appending(path: "regimens.json")
        try FileManager.default.removeItem(at: file)
        // A directory at the destination makes the atomic write fail reliably.
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        await #expect(throws: (any Error).self) { try await repository.save(regimen(dose: 3)) }
        #expect(try await repository.regimens().first?.id == first.id)
    }

    @Test func invalidRegimenCannotReplaceStoredData() async throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = FileTrackingRepository(baseURL: url)
        var value = try regimen(dose: 2)
        try await repository.save(value)
        value.intervalHours = 0
        await #expect(throws: (any Error).self) { try await repository.save(value) }
        #expect(try await repository.regimens().first?.intervalHours == 168)
    }
}
