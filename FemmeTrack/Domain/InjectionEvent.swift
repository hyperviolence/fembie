import Foundation

/// Preserve the scheduled time independently of the user's correction.
nonisolated struct InjectionEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let regimenID: UUID
    let scheduledAt: Date
    let doseMilligramsOfEster: Double
    var adjustment: InjectionAdjustment = .none

}
