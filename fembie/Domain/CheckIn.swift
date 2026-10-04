import Foundation

/// Complete deliberate responses only; UI slider defaults must not become answers.
nonisolated struct CheckIn: Identifiable, Codable, Sendable {
    let id: UUID
    let recordedAt: Date
    let mood: Double
    let libido: Double
    let energy: Double
}
