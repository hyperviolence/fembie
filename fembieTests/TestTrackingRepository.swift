import Foundation
@testable import fembie

actor TestTrackingRepository: TrackingRepository {
    var storedRegimens: [Regimen]
    var storedLabResults: [LabResult] = []
    var failReads = false
    var failWrites = false
    var writeDelay: Duration = .zero
    private(set) var writes = 0

    init(regimens: [Regimen] = []) { storedRegimens = regimens }
    func configure(failReads: Bool = false, failWrites: Bool = false, writeDelay: Duration = .zero) {
        self.failReads = failReads
        self.failWrites = failWrites
        self.writeDelay = writeDelay
    }
    func regimens() throws -> [Regimen] {
        if failReads { throw CocoaError(.fileReadCorruptFile) }
        return storedRegimens
    }
    func injectionEvents() -> [InjectionEvent] { [] }
    func checkIns() -> [CheckIn] { [] }
    func labResults() throws -> [LabResult] {
        if failReads { throw CocoaError(.fileReadCorruptFile) }
        return storedLabResults
    }
    func save(_ result: LabResult) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedLabResults.append(result)
    }
    func deleteLabResult(id: UUID) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedLabResults.removeAll { $0.id == id }
    }
    func save(_ regimen: Regimen) async throws {
        writes += 1
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedRegimens = [regimen]
    }
    func save(_ event: InjectionEvent) { }
    func save(_ checkIn: CheckIn) { }
}
