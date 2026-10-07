import Foundation

nonisolated struct RegimenNotificationInput: Equatable, Sendable {
    let prediction: LevelsPredictionInput
    let preferences: RegimenNotificationPreferences
}
