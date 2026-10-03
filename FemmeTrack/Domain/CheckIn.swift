import Foundation

/// Complete deliberate responses only; UI slider defaults must not become answers.
nonisolated struct CheckIn: Identifiable, Codable, Sendable {
    let id: UUID
    let recordedAt: Date
    let mood: Int
    let libido: Int
    let energy: Int
    // TODO: Validate each response in 0...10 before saving.
}
