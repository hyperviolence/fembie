import Foundation

nonisolated enum LevelsPredictionError: LocalizedError {
    case unsupportedRegimen

    var errorDescription: String? {
        "No prediction model is available for the saved ester and route. Currently, intramuscular and subcutaneous EEn are supported."
    }
}
