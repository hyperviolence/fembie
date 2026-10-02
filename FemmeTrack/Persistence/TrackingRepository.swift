import Foundation

/// Local storage boundary. No implementation or cloud synchronization yet.
protocol TrackingRepository {
    func regimens() throws -> [Regimen]
    func injectionEvents() throws -> [InjectionEvent]
    func checkIns() throws -> [CheckIn]
    func save(_ regimen: Regimen) throws
    func save(_ event: InjectionEvent) throws
    func save(_ checkIn: CheckIn) throws
}
