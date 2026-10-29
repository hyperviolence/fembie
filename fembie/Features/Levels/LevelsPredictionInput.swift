import Foundation

/// Only the inputs used by the plot participate in its refresh identity.
nonisolated struct LevelsPredictionInput: Equatable, Sendable {
    let regimens: [Regimen]
    var isActive = true
    var calibrationEnabled = false
    var calibrationResult: LabResult? = nil

    init(regimens: [Regimen], isActive: Bool = true, calibrationEnabled: Bool = false,
         calibrationResult: LabResult? = nil) {
        self.regimens = regimens.sorted { $0.effectiveFrom < $1.effectiveFrom }
        self.isActive = isActive
        self.calibrationEnabled = calibrationEnabled
        self.calibrationResult = calibrationResult
    }

    /// Compatibility for call sites that intentionally operate on one regimen.
    init(regimen: Regimen?, isActive: Bool = true, calibrationEnabled: Bool = false,
         calibrationResult: LabResult? = nil) {
        self.init(regimens: regimen.map { [$0] } ?? [], isActive: isActive,
                  calibrationEnabled: calibrationEnabled, calibrationResult: calibrationResult)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isActive == rhs.isActive
            && lhs.calibrationEnabled == rhs.calibrationEnabled
            && lhs.calibrationResult == rhs.calibrationResult
            && lhs.regimens.count == rhs.regimens.count
            && zip(lhs.regimens, rhs.regimens).allSatisfy(regimensEqual)
    }

    private static func regimensEqual(_ left: Regimen, _ right: Regimen) -> Bool {
        left.id == right.id && left.ester == right.ester && left.route == right.route
            && left.doseMilligramsOfEster == right.doseMilligramsOfEster
            && left.intervalHours == right.intervalHours && left.effectiveFrom == right.effectiveFrom
            && left.effectiveUntil == right.effectiveUntil
            && left.injectionEvents.count == right.injectionEvents.count
            && zip(left.injectionEvents, right.injectionEvents).allSatisfy { a, b in
                a.id == b.id && a.regimenID == b.regimenID && a.scheduledAt == b.scheduledAt
                    && a.doseMilligramsOfEster == b.doseMilligramsOfEster && a.adjustment == b.adjustment
            }
    }
}
