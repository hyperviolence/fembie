import Foundation
import Testing
import EstradiolPK
@testable import fembie

private actor ControlledPredictionCalculator: LevelsPredictionCalculating {
    func predict(regimen: Regimen, now: Date, calibrationResult: LabResult?,
                 alignSamplesToHour: Bool,
                 horizon: LevelsPredictionHorizon) async throws -> [PredictionPoint] {
        if regimen.doseMilligramsOfEster == 1 {
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        return [
            PredictionPoint(
                timestamp: now,
                estradiolPicogramsPerMilliliter: regimen.doseMilligramsOfEster,
                rateOfChangePicogramsPerMilliliterPerHour: 0
            )
        ]
    }
}

@MainActor
struct LevelsViewModelStateTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen(dose: Double, route: EstradiolRoute = .intramuscular) throws -> Regimen {
        try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
                    doseMilligramsOfEster: dose, route: route, intervalHours: 24,
                    effectiveFrom: now, effectiveUntil: nil, timeZoneIdentifier: "UTC")
    }

    @Test func newerRefreshCannotBeOverwrittenByAnOlderPrediction() async throws {
        let model = LevelsViewModel(calculator: ControlledPredictionCalculator())
        let slow = Task {
            await model.refresh(input: LevelsPredictionInput(regimen: try regimen(dose: 1)), now: now)
        }
        await Task.yield()
        await model.refresh(input: LevelsPredictionInput(regimen: try regimen(dose: 2)), now: now)
        try await slow.value

        #expect(model.current?.estradiolPicogramsPerMilliliter == 2)
        #expect(model.points.map(\.estradiolPicogramsPerMilliliter) == [2])
        #expect(!model.isLoading)
    }

    @Test func cancelledRefreshDoesNotPublishAndClearsLoading() async throws {
        let model = LevelsViewModel(calculator: ControlledPredictionCalculator())
        let task = Task {
            await model.refresh(input: LevelsPredictionInput(regimen: try regimen(dose: 1)), now: now)
        }
        while !model.isLoading { await Task.yield() }
        task.cancel()
        try await task.value
        #expect(model.points.isEmpty)
        #expect(model.current == nil)
        #expect(!model.isLoading)
    }

    @Test func noRegimenAndUnsupportedRegimenClearPriorModelState() async throws {
        let model = LevelsViewModel(calculator: ControlledPredictionCalculator())
        await model.refresh(input: LevelsPredictionInput(regimen: try regimen(dose: 2)), now: now)
        #expect(model.current != nil)

        await model.refresh(input: LevelsPredictionInput(regimen: nil), now: now)
        #expect(model.points.isEmpty)
        #expect(model.current == nil)
        #expect(model.modelIdentifier == nil)
        #expect(model.message?.contains("Save") == true)

        var unsupported = try regimen(dose: 2)
        unsupported.ester = "Unsupported"
        await model.refresh(input: LevelsPredictionInput(regimen: unsupported), now: now)
        #expect(model.points.isEmpty)
        #expect(model.current == nil)
        #expect(model.modelIdentifier == nil)
        #expect(model.message != nil)
    }

    @Test func invalidCalibrationFallbackCannotOverwriteNewerRequest() async throws {
        struct Calculator: LevelsPredictionCalculating {
            func predict(regimen: Regimen, now: Date, calibrationResult: LabResult?,
                         alignSamplesToHour: Bool,
                         horizon: LevelsPredictionHorizon) async throws -> [PredictionPoint] {
                if calibrationResult != nil {
                    throw LevelsPredictionError.invalidCalibration("invalid")
                }
                if regimen.doseMilligramsOfEster == 1 {
                    try await Task.sleep(for: .milliseconds(100))
                }
                return [PredictionPoint(timestamp: now,
                    estradiolPicogramsPerMilliliter: regimen.doseMilligramsOfEster,
                    rateOfChangePicogramsPerMilliliterPerHour: 0)]
            }
        }

        let model = LevelsViewModel(calculator: Calculator())
        let lab = LabResult(id: UUID(), test: .e2, value: 100, recordedAt: now)
        let old = Task {
            await model.refresh(input: LevelsPredictionInput(
                regimen: try regimen(dose: 1),
                calibrationEnabled: true,
                calibrationResult: lab
            ), now: now)
        }
        await Task.yield()
        await model.refresh(input: LevelsPredictionInput(regimen: try regimen(dose: 2)), now: now)
        try await old.value
        #expect(model.current?.estradiolPicogramsPerMilliliter == 2)
        #expect(model.calibrationMessage == nil)
    }
}
