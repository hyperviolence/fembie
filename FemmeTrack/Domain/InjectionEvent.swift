import Foundation

/// Preserve the scheduled time independently of the user's correction.
nonisolated struct InjectionEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let regimenID: UUID
    let scheduledAt: Date
    let doseMilligramsOfEster: Double
    var adjustment: InjectionAdjustment = .none

    init(id: UUID, regimenID: UUID, scheduledAt: Date, doseMilligramsOfEster: Double,
         adjustment: InjectionAdjustment = .none) {
        self.id = id
        self.regimenID = regimenID
        self.scheduledAt = scheduledAt
        self.doseMilligramsOfEster = doseMilligramsOfEster
        self.adjustment = adjustment
    }

    private enum CodingKeys: String, CodingKey {
        case id, regimenID, scheduledAt, doseMilligramsOfEster, adjustment, statusChangedManually
    }

    // Read existing JSON without losing confirmations from the old boolean field.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        regimenID = try values.decode(UUID.self, forKey: .regimenID)
        scheduledAt = try values.decode(Date.self, forKey: .scheduledAt)
        doseMilligramsOfEster = try values.decode(Double.self, forKey: .doseMilligramsOfEster)
        adjustment = try values.decodeIfPresent(InjectionAdjustment.self, forKey: .adjustment) ?? .none
        if adjustment == .none, try values.decodeIfPresent(Bool.self, forKey: .statusChangedManually) == true {
            adjustment = .confirmed
        }
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(regimenID, forKey: .regimenID)
        try values.encode(scheduledAt, forKey: .scheduledAt)
        try values.encode(doseMilligramsOfEster, forKey: .doseMilligramsOfEster)
        try values.encode(adjustment, forKey: .adjustment)
    }
}
