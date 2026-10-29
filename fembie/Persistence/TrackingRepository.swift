import Foundation

/// An asynchronous storage boundary that can be implemented by an actor.
nonisolated protocol TrackingRepository: Sendable {
    func regimens() async throws -> [Regimen]
    func injectionEvents() async throws -> [InjectionEvent]
    func checkIns() async throws -> [CheckIn]
    func labResults() async throws -> [LabResult]
    /// Replaces the saved regimen, including its injection events.
    func save(_ regimen: Regimen) async throws
    func save(_ event: InjectionEvent) async throws
    func save(_ checkIn: CheckIn) async throws
    func save(_ result: LabResult) async throws
    func replaceTrackingData(regimens: [Regimen], injectionEvents: [InjectionEvent], checkIns: [CheckIn]) async throws
    func resetRegimenData() async throws
    func resetWellbeingData() async throws
    func deleteLabResult(id: UUID) async throws
}
