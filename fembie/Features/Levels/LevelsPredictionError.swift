import Foundation

nonisolated enum LevelsPredictionError: LocalizedError {
    case unsupportedRegimen
    case invalidCalibration(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedRegimen:
            "No prediction model is available for the saved ester and route. Currently, intramuscular and subcutaneous EEn are supported."
        case .invalidCalibration(let message): message
        }
    }
}
