import Foundation

nonisolated struct RegimenNotificationPreferences: Codable, Equatable, Sendable {
    var enabled = false
    var leadTime: RegimenNotificationLeadTime = .thirtyMinutes
}
