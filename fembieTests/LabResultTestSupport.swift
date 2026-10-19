import Foundation
@testable import fembie

extension LabResult {
    init(id: UUID, test: LabTest, value: Double, recordedAt: Date) {
        self.init(
            id: id,
            test: test,
            value: value,
            unit: test.unit.first ?? "",
            recordedAt: recordedAt
        )
    }
}
