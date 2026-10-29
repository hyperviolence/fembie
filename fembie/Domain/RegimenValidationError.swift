import Foundation

nonisolated enum RegimenValidationError: LocalizedError {
    case invalidDose
    case invalidInterval
    case invalidSchedule
    case tooManyEvents

    var errorDescription: String? {
        switch self {
        case .invalidDose: "Enter a finite dose greater than zero."
        case .invalidInterval: "Enter a finite interval greater than zero."
        case .invalidSchedule: "Check the first dose date and schedule time zone."
        case .tooManyEvents: "This schedule contains too many doses. Increase the interval or choose a later first dose."
        }
    }
}
