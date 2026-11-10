import Foundation

/// Preserve the scheduled time independently of the user's correction.
nonisolated struct InjectionEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let regimenID: UUID
    let scheduledAt: Date
    let doseMilligramsOfEster: Double
    var adjustment: InjectionAdjustment = .none

    var isIndividual = false

    init(id: UUID, regimenID: UUID, scheduledAt: Date, doseMilligramsOfEster: Double,
         adjustment: InjectionAdjustment = .none, isIndividual: Bool = false) {
        self.id = id
        self.regimenID = regimenID
        self.scheduledAt = scheduledAt
        self.doseMilligramsOfEster = doseMilligramsOfEster
        self.adjustment = adjustment
        self.isIndividual = isIndividual
    }

    private enum CodingKeys: String, CodingKey {
        case id, regimenID, scheduledAt, doseMilligramsOfEster, adjustment, isIndividual
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        regimenID = try values.decode(UUID.self, forKey: .regimenID)
        scheduledAt = try values.decode(Date.self, forKey: .scheduledAt)
        doseMilligramsOfEster = try values.decode(Double.self, forKey: .doseMilligramsOfEster)
        adjustment = try values.decode(InjectionAdjustment.self, forKey: .adjustment)
        // Older stores and exported files contain only recurring events.
        isIndividual = try values.decodeIfPresent(Bool.self, forKey: .isIndividual) ?? false
    }

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
