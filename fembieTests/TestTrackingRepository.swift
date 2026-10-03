import Foundation
@testable import FemmeTrack

actor TestTrackingRepository: TrackingRepository {
    var storedRegimens: [Regimen]
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
    func save(_ regimen: Regimen) async throws {
        writes += 1
        if writeDelay != .zero { try await Task.sleep(for: writeDelay) }
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        storedRegimens = [regimen]
    }
    func save(_ event: InjectionEvent) { }
    func save(_ checkIn: CheckIn) { }
}
