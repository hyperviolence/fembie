import Foundation

nonisolated struct CheckInReminderPreferences: Codable, Equatable {
    var enabled = false
    var hour = 20
    var minute = 0
}
