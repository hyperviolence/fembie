/// Chart and notification forecasts have independent lookahead windows.
nonisolated enum LevelsPredictionHorizon: Int, Sendable {
    case chart = 14
    case notifications = 90
}
