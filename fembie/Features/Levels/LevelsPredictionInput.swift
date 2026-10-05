import Foundation

/// Only the inputs used by the plot participate in its refresh identity.
nonisolated struct LevelsPredictionInput: Equatable, Sendable {
    let regimen: Regimen?
    var isActive = true
    var calibrationEnabled = false
    var calibrationResult: LabResult? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.isActive == rhs.isActive,
              lhs.calibrationEnabled == rhs.calibrationEnabled,
              lhs.calibrationResult == rhs.calibrationResult else { return false }
        switch (lhs.regimen, rhs.regimen) {
        case (nil, nil): return true
        case let (left?, right?):
            return left.id == right.id && left.ester == right.ester
                && left.route == right.route
                && left.doseMilligramsOfEster == right.doseMilligramsOfEster
                && left.intervalHours == right.intervalHours
                && left.effectiveFrom == right.effectiveFrom
                && left.effectiveUntil == right.effectiveUntil
                && left.injectionEvents.count == right.injectionEvents.count
                && zip(left.injectionEvents, right.injectionEvents).allSatisfy { a, b in
                    a.id == b.id && a.regimenID == b.regimenID && a.scheduledAt == b.scheduledAt
                        && a.doseMilligramsOfEster == b.doseMilligramsOfEster && a.adjustment == b.adjustment
                }
        default: return false
        }
    }
}
