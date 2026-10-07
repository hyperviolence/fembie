import Foundation

nonisolated struct RegimenNotificationEvent: Identifiable, Equatable, Sendable {
    static let identifierPrefix = "fembie.regimen."
    let injectionID: UUID
    let injectionAt: Date
    let timestamp: Date
    var id: String {
        "\(Self.identifierPrefix)\(injectionID).\(Int(timestamp.timeIntervalSince1970.rounded()))"
    }
}
