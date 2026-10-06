import Foundation

nonisolated struct CheckInReminderInput: Equatable {
    let preferences: CheckInReminderPreferences
    let isActive: Bool
}
