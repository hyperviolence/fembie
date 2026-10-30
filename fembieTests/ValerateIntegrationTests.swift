import Foundation
import Testing
import EstradiolPK
@testable import fembie

struct ValerateIntegrationTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor @Test func selectingValerateDefaultsToImportedRouteAndPersistsRegimen() async throws {
        let repository = TestTrackingRepository()
        let start = start
        let model = RegimenViewModel(repository: repository, locale: Locale(identifier: "en_US"), clock: { start })
        model.selectedRoute = .subcutaneous
        model.selectedEster = .estradiolValerate
        #expect(model.selectedRoute == .intramuscular)
        model.dose = "4"
        model.interval = "7"
        #expect(await model.saveRegimen())
        let saved = try #require(model.savedRegimen)
        #expect(saved.ester == EstradiolType.estradiolValerate.displayName)
        #expect(saved.doseMilligramsOfEster == 4)
        #expect(saved.route == .intramuscular)
        let reloaded = RegimenViewModel(repository: repository, clock: { start })
        await reloaded.load()
        let restored = try #require(reloaded.savedRegimen)
        #expect(restored.ester == saved.ester)
        #expect(LevelsPredictionCalculator.model(for: restored)?.modelIdentifier
            == ValerateIntramuscularModel().modelIdentifier)
    }

    @Test func unsupportedRoutesDoNotFallBackToIntramuscularModel() async throws {
        var regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolValerate.displayName,
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 168,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        for route in EstradiolRoute.allCases where route != .intramuscular {
            regimen.route = route
            #expect(LevelsPredictionCalculator.model(for: regimen) == nil)
            await #expect(throws: LevelsPredictionError.self) {
                try await LevelsPredictionCalculator().predict(regimen: regimen, now: start)
            }
        }
    }

    @MainActor @Test func levelsUseValerateWithSkippedAndMovedAdministrations() async throws {
        let draft = try Regimen(id: UUID(), ester: EstradiolType.estradiolValerate.displayName,
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 168,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        var regimen = try InjectionSchedule().extending(draft, through: start.addingTimeInterval(14 * 86_400))
        regimen.injectionEvents[0].adjustment = .skipped
        let moved = start.addingTimeInterval(9 * 86_400)
        regimen.injectionEvents[1].adjustment = .moved(actualAt: moved)
        let now = start.addingTimeInterval(10 * 86_400)
        let model = LevelsViewModel()
        await model.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        let current = try #require(model.current)
        let expected = try ValerateIntramuscularModel().predict(
            doses: [.init(timestamp: moved, milligramsOfEster: 4)], at: [now])[0]
        #expect(abs(current.estradiolPicogramsPerMilliliter - expected.estradiolPicogramsPerMilliliter) < 1e-9)
        #expect(abs(current.rateOfChangePicogramsPerMilliliterPerHour
            - expected.rateOfChangePicogramsPerMilliliterPerHour) < 1e-9)
        #expect(model.modelIdentifier == "estrannaise/valerate-intramuscular/v1")
        #expect(model.modelSource == "Model source: Estrannaise by alix")
        #expect(model.message == nil)
    }

    @Test func mixedEstersSumTheirOwnModels() async throws {
        let valerate = try Regimen(id: UUID(), ester: EstradiolType.estradiolValerate.displayName,
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 168,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let enanthate = try Regimen(id: UUID(), ester: EstradiolType.estradiolEnanthate.displayName,
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 168,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let now = start.addingTimeInterval(3 * 86_400)
        let calculator = LevelsPredictionCalculator()
        let combined = try await calculator.predict(regimens: [valerate, enanthate], now: now)
        let current = try #require(combined.first { $0.timestamp == now })
        let doses = [DoseAdministration(timestamp: start, milligramsOfEster: 4)]
        let ev = try ValerateIntramuscularModel().predict(doses: doses, at: [now])[0]
        let een = try EnanthateIntramuscularModel().predict(doses: doses, at: [now])[0]
        #expect(abs(current.estradiolPicogramsPerMilliliter
            - ev.estradiolPicogramsPerMilliliter - een.estradiolPicogramsPerMilliliter) < 1e-9)
        #expect(abs(current.rateOfChangePicogramsPerMilliliterPerHour
            - ev.rateOfChangePicogramsPerMilliliterPerHour - een.rateOfChangePicogramsPerMilliliterPerHour) < 1e-9)
    }
}
