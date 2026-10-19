/// Chart, detail, and notification forecasts have independent time windows.
nonisolated enum LevelsPredictionHorizon: Sendable {
    case chart
    case detail
    case notifications

    var futureDays: Int {
        switch self {
        case .chart: 14
        case .detail, .notifications: 90
        }
    }
}
