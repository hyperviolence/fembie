import Foundation

nonisolated enum LevelsPredictionError: LocalizedError {
    case unsupportedRegimen
    case invalidCalibration(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedRegimen:
            "No prediction model is available for the saved formulation and route. Intramuscular and subcutaneous EEn, intramuscular EV, and transdermal estradiol gel are supported."
        case .invalidCalibration(let message): message
        }
    }
}
