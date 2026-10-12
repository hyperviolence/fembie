import Foundation

/// Preserve the scheduled time independently of the user's correction.
nonisolated struct InjectionEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let regimenID: UUID
    let scheduledAt: Date
    let doseMilligramsOfEster: Double
    var adjustment: InjectionAdjustment = .none

    func validate(for expectedRegimenID: UUID? = nil) throws {
        guard expectedRegimenID.map({ $0 == regimenID }) ?? true,
              scheduledAt.timeIntervalSinceReferenceDate.isFinite,
              doseMilligramsOfEster.isFinite,
              doseMilligramsOfEster > 0 else {
            throw RegimenValidationError.invalidSchedule
        }
        if case .moved(let actualAt) = adjustment,
           !actualAt.timeIntervalSinceReferenceDate.isFinite {
            throw RegimenValidationError.invalidSchedule
        }
    }
}
