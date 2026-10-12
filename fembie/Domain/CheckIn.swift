import Foundation

/// Complete deliberate responses only; UI slider defaults must not become answers.
nonisolated struct CheckIn: Identifiable, Codable, Sendable {
    let id: UUID
    let recordedAt: Date
    let mood: Double
    let libido: Double
    let energy: Double

    func validate() throws {
        guard recordedAt.timeIntervalSinceReferenceDate.isFinite,
              mood.isFinite, libido.isFinite, energy.isFinite,
              (0...10).contains(mood), (0...10).contains(libido), (0...10).contains(energy) else {
            throw TrackingValidationError.invalidCheckIn
        }
    }
}
