import Foundation

/// A metric's stable identity and labels travel with each recorded answer.
nonisolated struct CustomWellbeingRating: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var label: String
    var lowLabel: String
    var highLabel: String
    var value: Double

    func validate() throws {
        guard [label, lowLabel, highLabel].allSatisfy({
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 100
        }), value.isFinite, (0...10).contains(value) else {
            throw TrackingValidationError.invalidCheckIn
        }
    }
}
