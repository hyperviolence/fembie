import Foundation
@testable import fembie

actor TestTrackingRepository: TrackingRepository {
    var storedRegimens: [Regimen]
    var storedInjectionEvents: [InjectionEvent] = []
    var storedCheckIns: [CheckIn] = []
    var storedLabResults: [LabResult] = []
    var failReads = false
    var failWrites = false
    var writeDelay: Duration = .zero
    var failReadsAfterWrite = false
    private(set) var writes = 0
    private(set) var checkInWrites = 0
    private(set) var labWrites = 0

    init(regimens: [Regimen] = []) {
        storedRegimens = regimens
    }

    func configure(failReads: Bool = false, failWrites: Bool = false, writeDelay: Duration = .zero,
                   failReadsAfterWrite: Bool = false) {
        self.failReads = failReads
        self.failWrites = failWrites
        self.writeDelay = writeDelay
        self.failReadsAfterWrite = failReadsAfterWrite
    }

    func seed(checkIns: [CheckIn]) {
        storedCheckIns = checkIns
    }

    func seed(labResults: [LabResult]) {
        storedLabResults = labResults
    }

    func regimens() throws -> [Regimen] {
        if failReads { throw CocoaError(.fileReadCorruptFile) }
        return storedRegimens
    }

    func injectionEvents() throws -> [InjectionEvent] {
        if failReads { throw CocoaError(.fileReadCorruptFile) }
        return storedInjectionEvents
    }

    func checkIns() throws -> [CheckIn] {
        if failReads { throw CocoaError(.fileReadCorruptFile) }
        return storedCheckIns
    }

    func labResults() throws -> [LabResult] {
        if failReads { throw CocoaError(.fileReadCorruptFile) }
        return storedLabResults
    }

    func save(_ result: LabResult) async throws {
        labWrites += 1
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        if let index = storedLabResults.firstIndex(where: { $0.id == result.id }) {
            storedLabResults[index] = result
        } else {
            storedLabResults.append(result)
        }
        if failReadsAfterWrite { failReads = true }
    }

    func deleteLabResult(id: UUID) async throws {
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedLabResults.removeAll { $0.id == id }
    }

    func deleteRegimen(id: UUID) async throws {
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedRegimens.removeAll { $0.id == id }
        storedInjectionEvents.removeAll { $0.regimenID == id }
    }

    func save(_ regimen: Regimen) async throws {
        writes += 1
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        if let index = storedRegimens.firstIndex(where: { $0.id == regimen.id }) {
            storedRegimens[index] = regimen
        } else {
            storedRegimens.append(regimen)
        }
        storedRegimens.sort { $0.effectiveFrom < $1.effectiveFrom }
    }

    func resetRegimenData() throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedRegimens = []
        storedInjectionEvents = []
    }

    func deleteCustomMetric(id: UUID) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        for index in storedCheckIns.indices {
            storedCheckIns[index].customRatings.removeAll { $0.id == id }
        }
    }

    func resetWellbeingData() throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedCheckIns = []
    }

    func save(_ event: InjectionEvent) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedInjectionEvents.removeAll { $0.id == event.id }
        storedInjectionEvents.append(event)
    }

    func replaceTrackingData(regimens: [Regimen], injectionEvents: [InjectionEvent], checkIns: [CheckIn]) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedRegimens = regimens
        storedInjectionEvents = injectionEvents
        storedCheckIns = checkIns
    }

    func save(_ checkIn: CheckIn) async throws {
        checkInWrites += 1
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedCheckIns.removeAll { $0.id == checkIn.id }
        storedCheckIns.append(checkIn)
        if failReadsAfterWrite { failReads = true }
    }
}
