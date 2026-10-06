import Foundation

nonisolated struct LevelNotificationEvent: Equatable, Sendable, Identifiable {
    static let identifierPrefix = "fembie.levels."
    let kind: LevelNotificationKind
    let timestamp: Date

    var id: String {
        "\(Self.identifierPrefix)\(kind.rawValue).\(Int64(timestamp.timeIntervalSince1970.rounded()))"
    }
}
