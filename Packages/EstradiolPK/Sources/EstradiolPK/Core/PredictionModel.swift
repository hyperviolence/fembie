import Foundation

public struct DoseAdministration: Sendable {
    public let timestamp: Date
    /// Injection models use mg of ester; gel uses mg of active estradiol applied.
    /// The legacy name is retained for source compatibility.
    public let milligramsOfEster: Double

    public init(timestamp: Date, milligramsOfEster: Double) {
        self.timestamp = timestamp
        self.milligramsOfEster = milligramsOfEster
    }
}

public struct PredictionPoint: Sendable {
    public let timestamp: Date
    public let estradiolPicogramsPerMilliliter: Double
    public let rateOfChangePicogramsPerMilliliterPerHour: Double

    public init(timestamp: Date, estradiolPicogramsPerMilliliter: Double,
                rateOfChangePicogramsPerMilliliterPerHour: Double) {
        self.timestamp = timestamp
        self.estradiolPicogramsPerMilliliter = estradiolPicogramsPerMilliliter
        self.rateOfChangePicogramsPerMilliliterPerHour = rateOfChangePicogramsPerMilliliterPerHour
    }
}

public protocol PredictionModel: Sendable {
    var modelIdentifier: String { get }
    var modelSource: String { get }
    func predict(doses: [DoseAdministration], at timestamps: [Date]) throws -> [PredictionPoint]
}

public enum PredictionError: Error {
    case modelNotImplemented
}
