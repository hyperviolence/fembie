import Foundation
import EstradiolPK

nonisolated protocol LevelsPredictionCalculating: Sendable {
    func predict(regimen: Regimen, now: Date, calibrationResult: LabResult?,
                 alignSamplesToHour: Bool, horizon: LevelsPredictionHorizon) async throws -> [PredictionPoint]
    func predict(regimens: [Regimen], now: Date, calibrationResult: LabResult?,
                 alignSamplesToHour: Bool, horizon: LevelsPredictionHorizon) async throws -> [PredictionPoint]
}

extension LevelsPredictionCalculating {
    func predict(regimens: [Regimen], now: Date, calibrationResult: LabResult?,
                 alignSamplesToHour: Bool, horizon: LevelsPredictionHorizon) async throws -> [PredictionPoint] {
        guard let regimen = regimens.first else { return [] }
        return try await predict(regimen: regimen, now: now, calibrationResult: calibrationResult,
                                 alignSamplesToHour: alignSamplesToHour, horizon: horizon)
    }
}

/// Runs numerical work off the main actor; never changes saved regimens.
actor LevelsPredictionCalculator: LevelsPredictionCalculating {
    nonisolated static func model(for regimen: Regimen) -> (any PredictionModel)? {
        if regimen.ester == EstradiolType.estradiolGel.displayName, regimen.route == .transdermal {
            return TransdermalGelModel()
        }
        if regimen.ester == EstradiolType.estradiolValerate.displayName, regimen.route == .intramuscular {
            return ValerateIntramuscularModel()
        }
        guard regimen.ester == EstradiolType.estradiolEnanthate.displayName else { return nil }
        switch regimen.route {
        case .intramuscular: return EnanthateIntramuscularModel()
        case .subcutaneous: return EnanthateSubcutaneousModel()
        default: return nil
        }
    }

    func predict(regimen: Regimen, now: Date, calibrationResult: LabResult? = nil, alignSamplesToHour: Bool = false, horizon: LevelsPredictionHorizon = .chart) throws -> [PredictionPoint] {
        try predict(regimens: [regimen], now: now, calibrationResult: calibrationResult,
                    alignSamplesToHour: alignSamplesToHour, horizon: horizon)
    }

    func predict(regimens: [Regimen], now: Date, calibrationResult: LabResult? = nil,
                 alignSamplesToHour: Bool = false, horizon: LevelsPredictionHorizon = .chart) throws -> [PredictionPoint] {
        guard !regimens.isEmpty, regimens.allSatisfy({ Self.model(for: $0) != nil }) else {
            throw LevelsPredictionError.unsupportedRegimen
        }
        // Notifications use a stable clock-hour grid so refreshes do not shift alerts.
        let anchor = alignSamplesToHour
            ? Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / 3_600) * 3_600) : now
        let requestedEnd = anchor.addingTimeInterval(Double(horizon.futureDays) * 86_400)
        let start = horizon == .detail
            ? regimens.map(\.effectiveFrom).min() ?? anchor
            : anchor.addingTimeInterval(-14 * 86_400)
        let end: Date
        if horizon == .detail, regimens.allSatisfy({ $0.effectiveUntil != nil }),
           let latestEnd = regimens.compactMap(\.effectiveUntil).max() {
            end = min(latestEnd, requestedEnd)
        } else {
            end = requestedEnd
        }
        guard start <= end else { return [] }
        // Hourly points; chart calls include now exactly. Include all preceding doses.
        let sampleCount = Int((end.timeIntervalSince(start) / 3_600).rounded(.down))
        var timestamps = (0...sampleCount).map { start.addingTimeInterval(Double($0) * 3_600) }
        if now >= start, now <= end, !timestamps.contains(now) {
            timestamps.append(now)
            timestamps.sort()
        }
        if let calibrationResult, calibrationResult.recordedAt >= start,
           calibrationResult.recordedAt <= end, !timestamps.contains(calibrationResult.recordedAt) {
            timestamps.append(calibrationResult.recordedAt)
            timestamps.sort()
        }
        var combined = timestamps.map {
            PredictionPoint(timestamp: $0, estradiolPicogramsPerMilliliter: 0,
                            rateOfChangePicogramsPerMilliliterPerHour: 0)
        }
        let grouped = Dictionary(grouping: regimens) { regimen in
            Self.model(for: regimen)?.modelIdentifier ?? "unsupported"
        }.sorted { $0.key < $1.key }
        for (groupIndex, group) in grouped.enumerated() {
            guard let representative = group.value.first,
                  let model = Self.model(for: representative) else {
                throw LevelsPredictionError.unsupportedRegimen
            }
            var doses: [DoseAdministration] = []
            for regimen in group.value {
                let extended = try InjectionSchedule().extending(regimen, through: end)
                doses += extended.injectionEvents.compactMap { event -> DoseAdministration? in
                    guard event.regimenID == regimen.id else { return nil }
                    let timestamp: Date
                    switch event.adjustment {
                    case .skipped: return nil
                    case .moved(let actualAt): timestamp = actualAt
                    case .none, .confirmed: timestamp = event.scheduledAt
                    }
                    return DoseAdministration(timestamp: timestamp,
                                              milligramsOfEster: event.doseMilligramsOfEster)
                }
            }
            doses.sort { $0.timestamp < $1.timestamp }
            let contribution = try model.predict(doses: doses, at: timestamps)
            let contributionByTimestamp = Dictionary(uniqueKeysWithValues: contribution.map { ($0.timestamp, $0) })
            let baselineByTimestamp: [Date: PredictionPoint]
            if groupIndex == grouped.startIndex {
                baselineByTimestamp = [:]
            } else {
                guard let baselineModel = Self.model(for: representative) else {
                    throw LevelsPredictionError.unsupportedRegimen
                }
                let baseline = try baselineModel.predict(doses: [], at: timestamps)
                baselineByTimestamp = Dictionary(uniqueKeysWithValues: baseline.map { ($0.timestamp, $0) })
            }
            combined = combined.map { total in
                guard let component = contributionByTimestamp[total.timestamp] else { return total }
                let baseline = baselineByTimestamp[total.timestamp]
                return PredictionPoint(timestamp: total.timestamp,
                    estradiolPicogramsPerMilliliter: total.estradiolPicogramsPerMilliliter
                        + component.estradiolPicogramsPerMilliliter
                        - (baseline?.estradiolPicogramsPerMilliliter ?? 0),
                    rateOfChangePicogramsPerMilliliterPerHour: total.rateOfChangePicogramsPerMilliliterPerHour
                        + component.rateOfChangePicogramsPerMilliliterPerHour
                        - (baseline?.rateOfChangePicogramsPerMilliliterPerHour ?? 0))
            }
        }
        guard let calibrationResult else { return combined }
        try calibrationResult.validate()
        guard calibrationResult.test == .e2,
              calibrationResult.unit.lowercased() == "pg/ml" else {
            throw LevelsPredictionError.invalidCalibration("Calibration requires an E2 result in pg/mL.")
        }
        guard calibrationResult.recordedAt <= now,
              calibrationResult.recordedAt >= (regimens.map(\.effectiveFrom).min() ?? now) else {
            throw LevelsPredictionError.invalidCalibration("The E2 result must be dated after treatment began and cannot be in the future.")
        }
        let reference = combined.min { abs($0.timestamp.timeIntervalSince(calibrationResult.recordedAt))
            < abs($1.timestamp.timeIntervalSince(calibrationResult.recordedAt)) }
        guard let reference else { return combined }
        let offset = calibrationResult.value - reference.estradiolPicogramsPerMilliliter
        return combined.map { point in
            let adjustedLevel = point.estradiolPicogramsPerMilliliter + offset
            return PredictionPoint(timestamp: point.timestamp,
                                   estradiolPicogramsPerMilliliter: max(0, adjustedLevel),
                                   rateOfChangePicogramsPerMilliliterPerHour: adjustedLevel <= 0
                                    ? 0 : point.rateOfChangePicogramsPerMilliliterPerHour)
        }
    }
}
