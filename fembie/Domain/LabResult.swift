import Foundation

nonisolated struct LabResult: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let test: LabTest
    let value: Double
    let unit: String
    let recordedAt: Date

    init(id: UUID, test: LabTest, value: Double, recordedAt: Date) {
        self.id = id
        self.test = test
        self.value = value
        self.unit = test.unit
        self.recordedAt = recordedAt
    }

    func validate() throws {
        guard value.isFinite, value >= 0 else { throw LabResultValidationError.invalidValue }
        guard !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LabResultValidationError.missingUnit
        }
        guard recordedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw LabResultValidationError.invalidDate
        }
    }
}
