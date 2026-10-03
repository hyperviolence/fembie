import Foundation
import EstradiolPK

/// Runs numerical work off the main actor; never changes saved regimens.
actor LevelsPredictionCalculator {
    nonisolated static func model(for regimen: Regimen) -> (any PredictionModel)? {
        guard regimen.ester == EstradiolType.estradiolEnanthate.displayName,
              regimen.route == .intramuscular else { return nil }
        return EnanthateIntramuscularModel()
    }

    func predict(regimen: Regimen, now: Date) throws -> [PredictionPoint] {
        guard let model = Self.model(for: regimen) else {
            throw LevelsPredictionError.unsupportedRegimen
        }
        let start = now.addingTimeInterval(-14 * 86_400)
        let end = now.addingTimeInterval(14 * 86_400)
        let extended = try InjectionSchedule().extending(regimen, through: end)
        let doses = extended.injectionEvents.compactMap { event -> DoseAdministration? in
            guard event.regimenID == regimen.id else { return nil }
            let timestamp: Date
            switch event.adjustment {
            case .skipped: return nil
            case .moved(let actualAt): timestamp = actualAt
            case .none, .confirmed: timestamp = event.scheduledAt
            }
            return DoseAdministration(timestamp: timestamp, milligramsOfEster: event.doseMilligramsOfEster)
        }
        // Hourly points, with now exactly on the grid. Include all preceding doses.
        let timestamps = (0...672).map { start.addingTimeInterval(Double($0) * 3_600) }
        return try model.predict(doses: doses, at: timestamps)
    }
}
