import Foundation

/// Native port of Estrannaise's EV IM single-dose model and parameter set.
/// Source: https://github.com/WHSAH/estrannaise.js (models.js, modeldata.js).
/// Copyright (c) 2025 alix; MIT license, included in LICENSE-Estrannaise.txt.
public struct ValerateIntramuscularModel: PredictionModel {
    public let modelIdentifier = "estrannaise/valerate-intramuscular/v1"
    public let modelSource = "Model source: Estrannaise by alix"

    public init() { }

    public func predict(doses: [DoseAdministration], at timestamps: [Date]) throws -> [PredictionPoint] {
        guard doses.allSatisfy({ $0.timestamp.timeIntervalSinceReferenceDate.isFinite
            && $0.milligramsOfEster.isFinite && $0.milligramsOfEster >= 0 }),
              timestamps.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
            throw ValeratePredictionError.invalidInput
        }

        // Rates are per day; dose is milligrams of ester, output is pg/mL.
        let scale = 478.0
        let k1 = 0.236
        let k2 = 4.85
        let k3 = 1.24
        let a = 1 / ((k1 - k2) * (k1 - k3))
        let b = -1 / ((k1 - k2) * (k2 - k3))
        let c = 1 / ((k1 - k3) * (k2 - k3))

        return try timestamps.map { timestamp in
            var level = 0.0
            var ratePerDay = 0.0
            for dose in doses {
                let days = timestamp.timeIntervalSince(dose.timestamp) / 86_400
                guard days > 0, dose.milligramsOfEster > 0 else { continue }
                let factor = dose.milligramsOfEster * scale * k1 * k2
                let term1 = a * exp(-k1 * days)
                let term2 = b * exp(-k2 * days)
                let term3 = c * exp(-k3 * days)
                level += factor * max(0, term1 + term2 + term3)
                ratePerDay += factor * (-k1 * term1 - k2 * term2 - k3 * term3)
            }
            guard level.isFinite, ratePerDay.isFinite else {
                throw ValeratePredictionError.nonFiniteResult
            }
            return PredictionPoint(timestamp: timestamp, estradiolPicogramsPerMilliliter: level,
                rateOfChangePicogramsPerMilliliterPerHour: ratePerDay / 24)
        }
    }
}
