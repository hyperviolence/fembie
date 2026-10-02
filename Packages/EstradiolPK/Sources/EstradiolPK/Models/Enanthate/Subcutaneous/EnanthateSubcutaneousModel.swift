import Foundation

/// No coefficients or synthetic medical estimates until evidence review is complete.
public struct EnanthateSubcutaneousModel: PredictionModel {
    public let modelIdentifier = "enanthate-subcutaneous/unimplemented"

    public init() { }

    public func predict(doses: [DoseAdministration], at timestamps: [Date]) throws -> [PredictionPoint] {
        // Placeholder model: sum of exponential decays per dose.
        // Not medically validated. For UI scaffolding only.
        let halfLifeHours: Double = 36.0
        let lambda = log(2) / (halfLifeHours * 3600.0) // decay constant per second
        let potency: Double = 100.0 // pg/mL per mg of ester (arbitrary placeholder)

        return timestamps.map { t in
            var level: Double = 0
            for dose in doses {
                let dt = t.timeIntervalSince(dose.timestamp) // seconds since dose
                if dt >= 0 {
                    level += potency * dose.milligramsOfEster * exp(-lambda * dt)
                }
            }
            // d/dt of level(t) = -lambda * level(t); convert to per-hour units
            let ratePerHour = (-lambda * level) * 3600.0
            return PredictionPoint(
                timestamp: t,
                estradiolPicogramsPerMilliliter: level,
                rateOfChangePicogramsPerMilliliterPerHour: ratePerHour
            )
        }
    }
}
