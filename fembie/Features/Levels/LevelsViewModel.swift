import Foundation
import Observation
import EstradiolPK

@MainActor
@Observable
final class LevelsViewModel {
    private(set) var modelIdentifier: String?
    private(set) var modelSource: String = "Model source loading..."
    private(set) var points: [PredictionPoint] = []
    private(set) var current: PredictionPoint?
    private(set) var message: String?
    private(set) var isLoading = false
    private(set) var calibrationMessage: String?

    @ObservationIgnored private let calculator = LevelsPredictionCalculator()
    @ObservationIgnored private var revision = 0

    func refresh(input: LevelsPredictionInput, now: Date = Date()) async {
        revision += 1
        let requestRevision = revision
        isLoading = false
        points = []
        current = nil
        message = nil
        calibrationMessage = nil
        modelIdentifier = nil
        guard let regimen = input.regimen else {
            message = "Save a regimen to see estimated levels."
            return
        }
        guard let predictionModel = LevelsPredictionCalculator.model(for: regimen) else {
            message = LevelsPredictionError.unsupportedRegimen.localizedDescription
            return
        }
        modelIdentifier = predictionModel.modelIdentifier
        modelSource = predictionModel.modelSource
        isLoading = true
        defer {
            if revision == requestRevision { isLoading = false }
        }
        do {
            let result: [PredictionPoint]
            do {
                result = try await calculator.predict(regimen: regimen, now: now,
                                                      calibrationResult: input.calibrationResult)
                guard !Task.isCancelled, revision == requestRevision else { return }
                if let lab = input.calibrationResult {
                    calibrationMessage = "Adjusted using the E2 result from \(lab.recordedAt.formatted(date: .abbreviated, time: .shortened))."
                } else if input.calibrationEnabled {
                    calibrationMessage = "No E2 result is saved. Add an E2 result to apply calibration."
                }
            } catch LevelsPredictionError.invalidCalibration(let reason) {
                result = try await calculator.predict(regimen: regimen, now: now)
                guard !Task.isCancelled, revision == requestRevision else { return }
                calibrationMessage = "Calibration not applied: \(reason)"
            }
            guard !Task.isCancelled, revision == requestRevision else { return }
            points = result
            current = result.first { $0.timestamp == now }
        } catch {
            guard !Task.isCancelled, revision == requestRevision else { return }
            message = "Could not calculate estimated levels: \(error.localizedDescription)"
        }
    }
    
}
