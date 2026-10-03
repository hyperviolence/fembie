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

    @ObservationIgnored private let calculator = LevelsPredictionCalculator()
    @ObservationIgnored private var revision = 0

    func refresh(input: LevelsPredictionInput, now: Date = Date()) async {
        revision += 1
        let requestRevision = revision
        isLoading = false
        points = []
        current = nil
        message = nil
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
            let result = try await calculator.predict(regimen: regimen, now: now)
            guard !Task.isCancelled, revision == requestRevision else { return }
            points = result
            current = result.first { $0.timestamp == now }
        } catch {
            guard !Task.isCancelled, revision == requestRevision else { return }
            message = "Could not calculate estimated levels: \(error.localizedDescription)"
        }
    }
    
}
