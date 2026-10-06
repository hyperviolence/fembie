import Foundation
import EstradiolPK

nonisolated enum LevelNotificationKind: String, CaseIterable, Codable, Sendable {
    case e2Peak, e2Low, rateHighest, rateLowest

    var label: String {
        switch self {
        case .e2Peak: "E2 is at its peak"
        case .e2Low: "E2 is at its low"
        case .rateHighest: "The rate-of-change is the highest"
        case .rateLowest: "The rate-of-change is the lowest"
        }
    }

    var notificationBody: String {
        switch self {
        case .e2Peak: "E2 levels are currently at their highest. Open fembie to view your graph."
        case .e2Low: "E2 levels are currently at their lowest. Open fembie to view your graph."
        case .rateHighest: "E2 rate-of-change is at its highest now. Open fembie to view your graph."
        case .rateLowest: "E2 rate-of-change is at its lowest now. Open fembie to view your graph."
        }
    }

    var value: KeyPath<PredictionPoint, Double> {
        switch self {
        case .e2Peak, .e2Low: \.estradiolPicogramsPerMilliliter
        case .rateHighest, .rateLowest: \.rateOfChangePicogramsPerMilliliterPerHour
        }
    }

    var isMaximum: Bool { self == .e2Peak || self == .rateHighest }
}
