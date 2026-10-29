import Foundation

/// Dose-only approximation combining EstroGel and Divigel label summaries.
/// Input is mg of estradiol applied, not grams of gel or an absorbed dose.
/// See Evidence/TransdermalGel.md for derivation and substantial limitations.
public struct TransdermalGelModel: PredictionModel {
    public let modelIdentifier = "fembie/transdermal-gel/v1"
    public let modelSource = "Generic gel approximation based on EstroGel and Divigel prescribing information"

    public init() { }

    public func predict(doses: [DoseAdministration], at timestamps: [Date]) throws -> [PredictionPoint] {
        guard doses.allSatisfy({ $0.timestamp.timeIntervalSinceReferenceDate.isFinite
            && $0.milligramsOfEster.isFinite && $0.milligramsOfEster >= 0 }),
              timestamps.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
            throw GelPredictionError.invalidInput
        }

        // Rates are per hour. Common absorption rate reproduces Divigel's
        // median 8-hour steady-state Tmax at 1 mg/day in a Bateman response.
        let absorption = 0.11041559302643777
        let terminalRates: [Double] = [log(2.0) / 36, log(2.0) / 10]
        // AUC per applied mg: EstroGel's 0.75 mg arm and a through-origin
        // least-squares slope over all three Divigel dose/mean-level pairs.
        let exposures = [24 * 28.3 / 0.75,
                         24 * (0.25 * 9.8 + 0.5 * 21 + 30.5) / (0.25 * 0.25 + 0.5 * 0.5 + 1)]

        return try timestamps.map { timestamp in
            var level = 0.0
            var rate = 0.0
            for dose in doses {
                let hours = timestamp.timeIntervalSince(dose.timestamp) / 3_600
                guard hours.isFinite else { throw GelPredictionError.invalidInput }
                guard hours > 0, dose.milligramsOfEster > 0 else { continue }
                for (terminal, exposure) in zip(terminalRates, exposures) {
                    let slow = exp(-terminal * hours)
                    let fast = exp(-absorption * hours)
                    let scale = exposure * absorption * terminal / (absorption - terminal) / 2
                    // expm1 avoids cancellation immediately after application.
                    let response = slow * -expm1(-(absorption - terminal) * hours)
                    level += dose.milligramsOfEster * (scale * response)
                    rate += dose.milligramsOfEster * (scale * (absorption * fast - terminal * slow))
                }
            }
            guard level.isFinite, rate.isFinite else { throw GelPredictionError.nonFiniteResult }
            return PredictionPoint(timestamp: timestamp, estradiolPicogramsPerMilliliter: level,
                                   rateOfChangePicogramsPerMilliliterPerHour: rate)
        }
    }
}
