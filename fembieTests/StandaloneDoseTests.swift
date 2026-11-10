import Foundation
import Testing
@testable import fembie

@MainActor
struct StandaloneDoseTests {
    @Test(arguments: [EstradiolType.estradiolEnanthate, .estradiolValerate, .estradiolGel])
    func supportedFormulationsCanBeRecordedWithoutARegimen(_ ester: EstradiolType) async throws {
        let directory = URL.temporaryDirectory.appending(path: "StandaloneDose-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = FileTrackingRepository(baseURL: directory)
        let model = RegimenViewModel(repository: repository, locale: Locale(identifier: "en_US"), clock: { now })
        await model.load()
        let route = try #require(EsterRoutes.getRoutes(ester: ester).first)
        try await model.addStandaloneDose(ester: ester, route: route, date: now,
                                          doseText: "2.5", color: .purple)
        #expect(model.recurringRegimens.isEmpty)
        #expect(model.activeRegimens.isEmpty)
        #expect(model.savedRegimen == nil)
        let treatment = try #require(model.regimens.first)
        #expect(treatment.ester == ester.displayName)
        #expect(treatment.route == route)
        #expect(treatment.color == .purple)
        #expect(!treatment.isRecurring)
        #expect(model.visibleEvents.count == 1)
        #expect(model.visibleEvents.first?.adjustment == .confirmed)
        #expect(model.visibleEvents.first?.doseMilligramsOfEster == 2.5)
        let extended = try InjectionSchedule().extending(treatment, through: now.addingTimeInterval(10 * 365 * 86400))
        #expect(extended.injectionEvents.count == 1)
        #expect(try InjectionSchedule().eventCount(for: treatment, through: now.addingTimeInterval(86400)) == 0)
        let reloaded = RegimenViewModel(repository: FileTrackingRepository(baseURL: directory), clock: { now })
        await reloaded.load()
        #expect(reloaded.recurringRegimens.isEmpty)
        #expect(reloaded.visibleEvents.count == 1)
        #expect(reloaded.loadError == nil)
        let file = try await DataExporter(repository: repository).makeFile()
        let destination = FileTrackingRepository(baseURL: directory.appending(path: "imported"))
        try await DataImporter(repository: destination).importData(file.data)
        let imported = try #require(try await destination.regimens().first)
        #expect(!imported.isRecurring)
        #expect(try InjectionSchedule().extending(imported, through: now.addingTimeInterval(86400 * 365)).injectionEvents.count == 1)
        let snapshot = try await repository.syncSnapshot()
        try snapshot.validate()
        #expect(try snapshot.values(Regimen.self, prefix: "regimen/").first?.individualDoseOnly == true)
    }

    @Test func standaloneFutureDoseSchedulesOnlyOneReminder() async throws {
        let directory = URL.temporaryDirectory.appending(path: "StandaloneDose-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date()
        let model = RegimenViewModel(repository: FileTrackingRepository(baseURL: directory), clock: { now })
        await model.load()
        try await model.addStandaloneDose(ester: .estradiolValerate, route: .intramuscular,
                                          date: now.addingTimeInterval(7200), doseText: "2", color: nil)
        let treatment = try #require(model.regimens.first)
        #expect(treatment.injectionEvents.first?.adjustment == InjectionAdjustment.none)
        let reminders = try RegimenReminderCalculator().events(regimen: treatment, leadTime: .oneHour, now: now)
        #expect(reminders.count == 1)
        let points = try await LevelsPredictionCalculator().predict(regimen: treatment, now: now)
        #expect(!points.isEmpty)
    }

    @Test(arguments: [EstradiolType.estradiolUndecyclate, .estradiolOral, .estradiolPatch])
    func unsupportedFormulationsCannotBeSaved(_ ester: EstradiolType) async throws {
        let directory = URL.temporaryDirectory.appending(path: "UnsupportedDose-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let model = RegimenViewModel(repository: repository)
        await model.load()
        for route in EsterRoutes.getRoutes(ester: ester) {
            #expect(LevelsPredictionCalculator.model(ester: ester.displayName, route: route) == nil)
            await #expect(throws: LevelsPredictionError.self) {
                try await model.addStandaloneDose(ester: ester, route: route, date: .now,
                                                  doseText: "2", color: nil)
            }
        }
        #expect(model.regimens.isEmpty)
        #expect(try await repository.regimens().isEmpty)
    }

    @Test func standaloneValidationRejectsInvalidRouteAndAmount() async throws {
        let directory = URL.temporaryDirectory.appending(path: "StandaloneDose-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = RegimenViewModel(repository: FileTrackingRepository(baseURL: directory))
        await model.load()
        await #expect(throws: (any Error).self) {
            try await model.addStandaloneDose(ester: .estradiolGel, route: .intramuscular,
                                              date: .now, doseText: "2", color: nil)
        }
        await #expect(throws: (any Error).self) {
            try await model.addStandaloneDose(ester: .estradiolEnanthate, route: .intramuscular,
                                              date: .now, doseText: "0", color: nil)
        }
        #expect(model.regimens.isEmpty)
    }
}
