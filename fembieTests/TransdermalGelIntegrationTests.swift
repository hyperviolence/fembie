import Foundation
import Testing
import EstradiolPK
import UserNotifications
@testable import fembie

struct TransdermalGelIntegrationTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor @Test func selectingGelUpdatesRouteAndSavesOnlyActiveEstradiolDose() async throws {
        let repository = TestTrackingRepository()
        let start = start
        let model = RegimenViewModel(repository: repository, locale: Locale(identifier: "en_US"), clock: { start })
        model.selectedRoute = .subcutaneous
        model.selectedEster = .estradiolGel
        #expect(model.selectedRoute == .transdermal)
        model.dose = "0.75"
        model.intervalUnit = .hours
        model.interval = "12"
        await model.saveRegimen()
        let saved = try #require(model.savedRegimen)
        #expect(saved.ester == EstradiolType.estradiolGel.displayName)
        #expect(saved.doseMilligramsOfEster == 0.75)
        #expect(saved.intervalHours == 12)
        #expect(saved.injectionEvents.allSatisfy { $0.doseMilligramsOfEster == 0.75 })
        let reloaded = RegimenViewModel(repository: repository, clock: { start })
        await reloaded.load()
        #expect(reloaded.savedRegimen?.route == .transdermal)
        #expect(reloaded.savedRegimen?.doseMilligramsOfEster == 0.75)
        model.selectedEster = .estradiolEnanthate
        #expect(model.selectedRoute == .subcutaneous)
    }

    @Test func modelSelectionRejectsMismatchedFormulationsAndRoutes() throws {
        var regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolGel.displayName,
            doseMilligramsOfEster: 1, route: .transdermal, intervalHours: 24,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        #expect(LevelsPredictionCalculator.model(for: regimen)?.modelIdentifier == TransdermalGelModel().modelIdentifier)
        for route in EstradiolRoute.allCases where route != .transdermal {
            regimen.route = route
            #expect(LevelsPredictionCalculator.model(for: regimen) == nil)
        }
        regimen.route = .transdermal
        regimen.ester = EstradiolType.estradiolPatch.displayName
        #expect(LevelsPredictionCalculator.model(for: regimen) == nil)
    }

    @MainActor @Test func savedGelUsesActualApplicationsAndDisplaysCorrectProvenance() async throws {
        var regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolGel.displayName,
            doseMilligramsOfEster: 0.75, route: .transdermal, intervalHours: 24,
            effectiveFrom: start, effectiveUntil: start.addingTimeInterval(2 * 86_400), timeZoneIdentifier: "UTC")
        regimen = try InjectionSchedule().extending(regimen, through: start.addingTimeInterval(2 * 86_400))
        regimen.injectionEvents[0].adjustment = .skipped
        let applied = start.addingTimeInterval(26 * 3_600)
        regimen.injectionEvents[1].adjustment = .moved(actualAt: applied)
        let now = start.addingTimeInterval(30 * 3_600)
        let viewModel = LevelsViewModel()
        await viewModel.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        let current = try #require(viewModel.current)
        let expected = try TransdermalGelModel().predict(
            doses: [.init(timestamp: applied, milligramsOfEster: 0.75)], at: [now])[0]
        #expect(abs(current.estradiolPicogramsPerMilliliter - expected.estradiolPicogramsPerMilliliter) < 1e-10)
        #expect(abs(current.rateOfChangePicogramsPerMilliliterPerHour
            - expected.rateOfChangePicogramsPerMilliliterPerHour) < 1e-10)
        #expect(viewModel.modelIdentifier == "fembie/transdermal-gel/v1")
        #expect(viewModel.modelSource.contains("EstroGel and Divigel"))
        #expect(viewModel.message == nil)
        #expect(viewModel.points.filter { $0.timestamp <= applied }
            .allSatisfy { $0.estradiolPicogramsPerMilliliter == 0 })
    }

    @Test func gelCalibrationAndReminderSchedulingUseExistingDosePipeline() async throws {
        let regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolGel.displayName,
            doseMilligramsOfEster: 1, route: .transdermal, intervalHours: 12,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let now = start.addingTimeInterval(4 * 3_600)
        let lab = LabResult(id: UUID(), test: .e2, value: 42, unit: "pg/mL", recordedAt: now)
        let points = try await LevelsPredictionCalculator().predict(regimen: regimen, now: now, calibrationResult: lab)
        let current = try #require(points.first { $0.timestamp == now })
        #expect(abs(current.estradiolPicogramsPerMilliliter - 42) < 1e-10)
        let events = try RegimenReminderCalculator().events(regimen: regimen, leadTime: .oneHour, now: now)
        #expect(!events.isEmpty)
        #expect(events.first?.injectionAt == start.addingTimeInterval(12 * 3_600))
        let event = try #require(events.first)
        #expect(RegimenNotificationScheduler.contentBody(for: event).contains("dose scheduled"))
        #expect(RegimenNotificationScheduler.request(for: event).content.title == "fembie · Dose reminder")
    }
}
