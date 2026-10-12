import Foundation

nonisolated enum TrackingValidationError: LocalizedError {
    case invalidCheckIn

    var errorDescription: String? {
        switch self {
        case .invalidCheckIn:
            "Check-in responses must be finite values in the range 0...10 with a valid date."
        }
    }
}
