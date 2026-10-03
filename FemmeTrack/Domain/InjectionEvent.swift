import Foundation

/// Preserve the scheduled time independently of the user's correction.
struct InjectionEvent: Identifiable, Codable {
    let id: UUID
    let regimenID: UUID
    let scheduledAt: Date
    let doseMilligramsOfEster: Double
    var adjustment: Adjustment = .none

    enum Adjustment: Codable {
        case none // Upcoming or assumed taken, depending on the current time.
        case skipped
        case moved(actualAt: Date)
    }
}
