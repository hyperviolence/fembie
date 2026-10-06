import Foundation

nonisolated struct LevelsNotificationPreferences: Codable, Equatable, Sendable {
    var enabled = false
    var kinds: Set<LevelNotificationKind> = []
}
