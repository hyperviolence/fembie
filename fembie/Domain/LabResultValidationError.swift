import Foundation

nonisolated enum LabResultValidationError: LocalizedError {
    case invalidValue
    case missingUnit
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .invalidValue: "Enter a valid number greater than or equal to zero."
        case .missingUnit: "Enter the unit shown on your lab report."
        case .invalidDate: "Enter a valid date and time."
        }
    }
}
