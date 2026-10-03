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
        case .invalidSchedule: "Check the first injection date and schedule time zone."
        case .tooManyEvents: "This schedule contains too many injections. Increase the interval or choose a later first injection."
        }
    }
}
