import Foundation

/// No coefficients or synthetic medical estimates until evidence review is complete.
public struct EnanthateSubcutaneousModel: PredictionModel {
    public let modelIdentifier = "enanthate-subcutaneous/unimplemented"

    public init() { }

    public func predict(doses: [DoseAdministration], at timestamps: [Date]) throws -> [PredictionPoint] {
        throw PredictionError.modelNotImplemented
    }
}
