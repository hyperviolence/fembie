import Foundation

/// A single persisted override; no override means upcoming or assumed taken.
nonisolated enum InjectionAdjustment: Codable, Equatable, Sendable {
    case none
    case confirmed
    case skipped
    case moved(actualAt: Date)
}
