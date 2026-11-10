import Foundation

/// Complete deliberate responses only; UI slider defaults must not become answers.
nonisolated struct CheckIn: Identifiable, Codable, Sendable {
    let id: UUID
    let recordedAt: Date
    let mood: Double
    let libido: Double
    let energy: Double

    var customRatings: [CustomWellbeingRating] = []

    private enum CodingKeys: String, CodingKey {
        case id, recordedAt, mood, libido, energy, customRatings
    }

    init(id: UUID, recordedAt: Date, mood: Double, libido: Double, energy: Double,
         customRatings: [CustomWellbeingRating] = []) {
        self.id = id
        self.recordedAt = recordedAt
        self.mood = mood
        self.libido = libido
        self.energy = energy
        self.customRatings = customRatings
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        recordedAt = try values.decode(Date.self, forKey: .recordedAt)
        mood = try values.decode(Double.self, forKey: .mood)
        libido = try values.decode(Double.self, forKey: .libido)
        energy = try values.decode(Double.self, forKey: .energy)
        // Existing stores and exports predate custom metrics.
        customRatings = try values.decodeIfPresent([CustomWellbeingRating].self, forKey: .customRatings) ?? []
    }

    func validate() throws {
        guard Set(customRatings.map(\.id)).count == customRatings.count else {
            throw TrackingValidationError.invalidCheckIn
        }
        for rating in customRatings { try rating.validate() }
        guard recordedAt.timeIntervalSinceReferenceDate.isFinite,
              mood.isFinite, libido.isFinite, energy.isFinite,
              (0...10).contains(mood), (0...10).contains(libido), (0...10).contains(energy) else {
            throw TrackingValidationError.invalidCheckIn
        }
    }
}
