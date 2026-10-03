import Foundation
import Testing
import EstradiolPK
@testable import FemmeTrack

struct LevelsPredictionCalculatorTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen() throws -> Regimen {
        let regimen = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 7 * 24, effectiveFrom: start,
            effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
        return try InjectionSchedule().extending(regimen, through: start.addingTimeInterval(14 * 86_400))
    }

    @Test func skippedAndMovedEventsUseEffectiveTimes() async throws {
        var input = try regimen()
        input.injectionEvents[0].adjustment = .skipped
        input.injectionEvents[1].adjustment = .moved(actualAt: start.addingTimeInterval(9 * 86_400))
        let now = start.addingTimeInterval(10 * 86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let current = try #require(points.first { $0.timestamp == now })
        let expected = try EnanthateIntramuscularModel().predict(
            doses: [DoseAdministration(timestamp: start.addingTimeInterval(9 * 86_400), milligramsOfEster: 4)], at: [now])
        #expect(abs(current.estradiolPicogramsPerMilliliter - expected[0].estradiolPicogramsPerMilliliter) < 1e-9)
        #expect(points.count == 673)
    }

    @Test func doseMovedIntoFutureCannotAffectCurrentEstimate() async throws {
        var input = try regimen()
        input.injectionEvents[0].adjustment = .moved(actualAt: start.addingTimeInterval(3 * 86_400))
        let now = start.addingTimeInterval(86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let current = try #require(points.first { $0.timestamp == now })
        #expect(current.estradiolPicogramsPerMilliliter == 0)
        #expect(points.last?.estradiolPicogramsPerMilliliter ?? 0 > 0)
    }

    @MainActor @Test func selectsModelFromSavedEsterAndRoute() async throws {
        let model = LevelsViewModel()
        var input = try regimen()
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: start)
        #expect(model.current != nil)
        #expect(model.modelIdentifier == EnanthateIntramuscularModel().modelIdentifier)
        #expect(model.message == nil)
        input.route = .subcutaneous
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: start)
        #expect(model.current != nil)
        #expect(model.points.count == 673)
        #expect(model.modelIdentifier == EnanthateSubcutaneousModel().modelIdentifier)
        #expect(model.message == nil)
        input.route = .intramuscular
        input.ester = "Estradiol Valerate (EV)"
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: start)
        #expect(model.current == nil)
        #expect(model.message != nil)
    }

    @Test func unsupportedRoutesCannotUseIntramuscularCalculation() async throws {
        var input = try regimen()
        for route in EstradiolRoute.allCases where route != .intramuscular && route != .subcutaneous {
            input.route = route
            await #expect(throws: LevelsPredictionError.self) {
                try await LevelsPredictionCalculator().predict(regimen: input, now: start)
            }
        }
    }

    @Test func subcutaneousPredictionsUseAdjustedModel() async throws {
        var input = try regimen()
        input.route = .subcutaneous
        let now = start.addingTimeInterval(3 * 86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let current = try #require(points.first { $0.timestamp == now })
        let expected = try EnanthateSubcutaneousModel().predict(
            doses: [DoseAdministration(timestamp: start, milligramsOfEster: 4)], at: [now])
        #expect(abs(current.estradiolPicogramsPerMilliliter - expected[0].estradiolPicogramsPerMilliliter) < 1e-9)
        #expect(abs(current.rateOfChangePicogramsPerMilliliterPerHour
            - expected[0].rateOfChangePicogramsPerMilliliterPerHour) < 1e-9)
    }

    @Test func correctionsInvalidatePlotIdentity() throws {
        let original = try regimen()
        var edited = original
        edited.injectionEvents[0].adjustment = .skipped
        #expect(LevelsPredictionInput(regimen: original) != LevelsPredictionInput(regimen: edited))
        edited = original
        edited.route = .subcutaneous
        #expect(LevelsPredictionInput(regimen: original) != LevelsPredictionInput(regimen: edited))
    }
}
