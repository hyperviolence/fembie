import Foundation

nonisolated struct LevelsNotificationInput: Equatable, Sendable {
    let prediction: LevelsPredictionInput
    let preferences: LevelsNotificationPreferences
}
