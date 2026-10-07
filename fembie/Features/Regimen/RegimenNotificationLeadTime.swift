import Foundation

nonisolated enum RegimenNotificationLeadTime: Int, Codable, CaseIterable, Sendable {
    case thirtyMinutes = 1800
    case oneHour = 3600
    case threeHours = 10800
    case oneDay = 86400

    var label: String {
        switch self {
        case .thirtyMinutes: "30 minutes prior"
        case .oneHour: "1 hour prior"
        case .threeHours: "3 hours prior"
        case .oneDay: "1 day prior"
        }
    }
}
