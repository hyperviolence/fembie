import Foundation

nonisolated enum RegimenIntervalUnit: Int, CaseIterable {
    case days = 24
    case hours = 1

    var label: String {
        switch self {
        case .days: "Days"
        case .hours: "Hours"
        }
    }

    var fieldLabel: String {
        switch self {
        case .days: "Interval (days)"
        case .hours: "Interval (hours)"
        }
    }
}
