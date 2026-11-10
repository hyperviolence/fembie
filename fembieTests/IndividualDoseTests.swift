import Foundation
import Testing
import EstradiolPK
@testable import fembie

@MainActor
struct IndividualDoseTests {
    @Test func addingDosePreservesRecurrenceAndSurvivesEditingReloadExportAndSync() async throws {
        let directory = URL.temporaryDirectory.appending(path: "IndividualDose-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = FileTrackingRepository(baseURL: directory)
        let model = RegimenViewModel(repository: repository, locale: Locale(identifier: "en_US"), clock: { now })
        model.dose = "5"
        model.interval = "7"
        model.selectedColor = .teal
        #expect(await model.saveRegimen())
        let original = try #require(model.regimens.first)
        // Same timestamp as a recurring dose must not replace that dose.
        try await model.addIndividualDose(regimenID: original.id, date: now, doseText: "2.5")
        let added = try #require(model.regimens.first?.injectionEvents.first(where: { $0.isIndividual }))
        #expect(added.adjustment == .confirmed)
        #expect(added.doseMilligramsOfEster == 2.5)
        #expect(model.regimens.count == 1)
        #expect(model.regimens.first?.injectionEvents.filter { !$0.isIndividual }.map(\.id) == original.injectionEvents.map(\.id))
        #expect(model.visibleEvents.contains { $0.id == added.id })
        await model.load()
        #expect(model.loadError == nil)
        model.beginEditing(try #require(model.regimens.first))
        model.dose = "6"
        model.interval = "5"
        model.firstInjection = now.addingTimeInterval(3600)
        #expect(await model.saveRegimen())
        let edited = try #require(model.regimens.first)
        #expect(edited.injectionEvents.first(where: { $0.isIndividual })?.id == added.id)
        #expect(edited.injectionEvents.first(where: { $0.isIndividual })?.doseMilligramsOfEster == 2.5)
        #expect(edited.color == .teal)
        let reloaded = RegimenViewModel(repository: FileTrackingRepository(baseURL: directory), clock: { now })
        await reloaded.load()
        #expect(reloaded.regimens.first?.injectionEvents.contains { $0.id == added.id } == true)
        let export = try await DataExporter(repository: repository).makeFile()
        let decoded = try DataImportValidator().decodeAndValidate(export.data)
        #expect(decoded.regimens.first?.injectionEvents.first(where: { $0.isIndividual })?.id == added.id)
        let snapshot = try await repository.syncSnapshot()
        try snapshot.validate()
        #expect(try snapshot.values(Regimen.self, prefix: "regimen/").first?.injectionEvents.first(where: { $0.isIndividual })?.id == added.id)
    }

    @Test func offScheduleAndOutsideRangeDosesSurviveExtension() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolEnanthate.displayName,
                                  doseMilligramsOfEster: 5, route: .intramuscular, intervalHours: 168,
                                  effectiveFrom: start, effectiveUntil: start.addingTimeInterval(86400), timeZoneIdentifier: "UTC")
        let doses = [-3600.0, 1200, 172800].map {
            InjectionEvent(id: UUID(), regimenID: regimen.id, scheduledAt: start.addingTimeInterval($0),
                           doseMilligramsOfEster: 2, isIndividual: true)
        }
        regimen.injectionEvents = doses
        let extended = try InjectionSchedule().extending(regimen, through: start.addingTimeInterval(604800))
        #expect(extended.injectionEvents.filter(\.isIndividual).map(\.id) == doses.map(\.id))
        #expect(extended.injectionEvents.filter { !$0.isIndividual }.count == 1)
        #expect(RegimenScheduleRepair.restoringScheduledDates(in: extended) == nil)
    }

    @Test func oldEventJSONDefaultsToRecurring() throws {
        let event = InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: .now, doseMilligramsOfEster: 5)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        object.removeValue(forKey: "isIndividual")
        let decoded = try JSONDecoder().decode(InjectionEvent.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(!decoded.isIndividual)
        #expect(decoded.id == event.id)
    }

    @Test func invalidOrFailedSaveDoesNotChangeRegimen() async throws {
        let directory = URL.temporaryDirectory.appending(path: "IndividualDose-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = RegimenViewModel(repository: FileTrackingRepository(baseURL: directory),
                                     locale: Locale(identifier: "en_US"))
        model.dose = "5"
        model.interval = "7"
        #expect(await model.saveRegimen())
        let saved = try #require(model.regimens.first)
        for input in ["0", "-1", "NaN", "bad"] {
            await #expect(throws: (any Error).self) {
                try await model.addIndividualDose(regimenID: saved.id, date: .now, doseText: input)
            }
        }
        await #expect(throws: (any Error).self) {
            try await model.addIndividualDose(regimenID: UUID(), date: .now, doseText: "2")
        }
        let file = directory.appending(path: "regimens.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        await #expect(throws: (any Error).self) {
            try await model.addIndividualDose(regimenID: saved.id, date: .now, doseText: "2")
        }
        #expect(model.regimens.first?.injectionEvents.count == saved.injectionEvents.count)
        #expect(!model.isBusy)
    }

    @Test func individualDoseContributesToPredictionAndFutureReminder() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolEnanthate.displayName,
                                  doseMilligramsOfEster: 5, route: .intramuscular, intervalHours: 168,
                                  effectiveFrom: now.addingTimeInterval(-86400), effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let calculator = LevelsPredictionCalculator()
        let baseline = try await calculator.predict(regimen: regimen, now: now)
        let past = InjectionEvent(id: UUID(), regimenID: regimen.id, scheduledAt: now.addingTimeInterval(-3600),
                                  doseMilligramsOfEster: 2, adjustment: .confirmed, isIndividual: true)
        let future = InjectionEvent(id: UUID(), regimenID: regimen.id, scheduledAt: now.addingTimeInterval(7200),
                                    doseMilligramsOfEster: 2, isIndividual: true)
        regimen.injectionEvents = [past, future]
        let prediction = try await calculator.predict(regimen: regimen, now: now)
        let predictedNow = try #require(prediction.first(where: { $0.timestamp == now }))
        let baselineNow = try #require(baseline.first(where: { $0.timestamp == now }))
        #expect(predictedNow.estradiolPicogramsPerMilliliter > baselineNow.estradiolPicogramsPerMilliliter)
        let reminders = try RegimenReminderCalculator().events(regimen: regimen, leadTime: .oneHour, now: now)
        #expect(reminders.contains { $0.injectionID == future.id })
        #expect(!reminders.contains { $0.injectionID == past.id })
    }
}
