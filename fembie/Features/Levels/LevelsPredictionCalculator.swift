import Foundation
import EstradiolPK

/// Runs numerical work off the main actor; never changes saved regimens.
actor LevelsPredictionCalculator {
    nonisolated static func model(for regimen: Regimen) -> (any PredictionModel)? {
        guard regimen.ester == EstradiolType.estradiolEnanthate.displayName else { return nil }
        switch regimen.route {
        case .intramuscular: return EnanthateIntramuscularModel()
        case .subcutaneous: return EnanthateSubcutaneousModel()
        default: return nil
        }
    }

    func predict(regimen: Regimen, now: Date, calibrationResult: LabResult? = nil, alignSamplesToHour: Bool = false, horizon: LevelsPredictionHorizon = .chart) throws -> [PredictionPoint] {
        guard let model = Self.model(for: regimen) else {
            throw LevelsPredictionError.unsupportedRegimen
        }
        // Notifications use a stable clock-hour grid so refreshes do not shift alerts.
        let anchor = alignSamplesToHour
            ? Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / 3_600) * 3_600) : now
        let start = anchor.addingTimeInterval(-14 * 86_400)
        let end = anchor.addingTimeInterval(Double(horizon.rawValue) * 86_400)
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
        // Hourly points; chart calls include now exactly. Include all preceding doses.
        let sampleCount = (14 + horizon.rawValue) * 24
        var timestamps = (0...sampleCount).map { start.addingTimeInterval(Double($0) * 3_600) }
        guard let calibrationResult else { return try model.predict(doses: doses, at: timestamps) }
        try calibrationResult.validate()
        guard calibrationResult.test == .e2,
              calibrationResult.unit.lowercased() == "pg/ml" else {
            throw LevelsPredictionError.invalidCalibration("Calibration requires an E2 result in pg/mL.")
        }
        guard calibrationResult.recordedAt <= now,
              calibrationResult.recordedAt >= regimen.effectiveFrom else {
            throw LevelsPredictionError.invalidCalibration("The E2 result must be dated within the current regimen and cannot be in the future.")
        }
        let reference = try model.predict(doses: doses, at: [calibrationResult.recordedAt])[0]
        let offset = calibrationResult.value - reference.estradiolPicogramsPerMilliliter
        // Include the exact measurement time even when it is between hourly samples.
        if calibrationResult.recordedAt >= start, !timestamps.contains(calibrationResult.recordedAt) {
            timestamps.append(calibrationResult.recordedAt)
            timestamps.sort()
        }
        return try model.predict(doses: doses, at: timestamps).map { point in
            let adjustedLevel = point.estradiolPicogramsPerMilliliter + offset
            return PredictionPoint(timestamp: point.timestamp,
                                   estradiolPicogramsPerMilliliter: max(0, adjustedLevel),
                                   rateOfChangePicogramsPerMilliliterPerHour: adjustedLevel <= 0
                                    ? 0 : point.rateOfChangePicogramsPerMilliliterPerHour)
        }
    }
}
