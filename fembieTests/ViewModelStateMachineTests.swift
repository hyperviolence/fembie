import Foundation
import Testing
import EstradiolPK
@testable import fembie

private actor SlowNotificationPredictionCalculator: LevelsPredictionCalculating {
    func predict(regimen: Regimen, now: Date, calibrationResult: LabResult?,
                 alignSamplesToHour: Bool,
                 horizon: LevelsPredictionHorizon) async throws -> [PredictionPoint] {
        try await Task.sleep(for: .milliseconds(100))
        return [
            PredictionPoint(timestamp: now.addingTimeInterval(3_600),
                            estradiolPicogramsPerMilliliter: 1,
                            rateOfChangePicogramsPerMilliliterPerHour: 0),
            PredictionPoint(timestamp: now.addingTimeInterval(7_200),
                            estradiolPicogramsPerMilliliter: 3,
                            rateOfChangePicogramsPerMilliliterPerHour: 0),
            PredictionPoint(timestamp: now.addingTimeInterval(10_800),
                            estradiolPicogramsPerMilliliter: 1,
                            rateOfChangePicogramsPerMilliliterPerHour: 0)
        ]
    }
}

@MainActor
struct ViewModelStateMachineTests {
    private func settings() throws -> (UserDefaults, String) {
        let name = "ViewModelStateMachineTests-\(UUID())"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func checkInLoadFailureRecoversAndClearsHistoryError() async {
        let repository = TestTrackingRepository()
        await repository.configure(failReads: true)
        let model = CheckInViewModel(repository: repository)
        await model.loadCheckIns()
        #expect(model.historyError != nil)
        #expect(!model.isBusy)

        await repository.configure()
        await repository.seed(checkIns: [
            CheckIn(id: UUID(), recordedAt: .now, mood: 5, libido: 5, energy: 5)
        ])
        await model.loadCheckIns()
        #expect(model.checkIns.count == 1)
        #expect(model.historyError == nil)
    }

    @Test func checkInSuccessfulSaveCanReportARefreshFailureWithoutLosingConfirmation() async {
        let repository = TestTrackingRepository()
        await repository.configure(failReadsAfterWrite: true)
        let model = CheckInViewModel(repository: repository)
        let date = Date(timeIntervalSince1970: 100)
        await model.saveCheckIn(date: date, mood: 5, libido: 6, energy: 7)

        #expect(model.lastSavedCheckInDate == date)
        #expect(model.saveError == nil)
        #expect(model.historyError?.contains("saved") == true)
        #expect(await repository.storedCheckIns.count == 1)
        #expect(!model.isBusy)
    }

    @Test func checkInBusyLoadRejectsSaveAndResetAndPreventsConcurrentWrites() async {
        let repository = TestTrackingRepository()
        await repository.configure(writeDelay: .milliseconds(100))
        let model = CheckInViewModel(repository: repository)
        let first = Task { await model.saveCheckIn(date: .now, mood: 5, libido: 5, energy: 5) }
        while !model.isBusy { await Task.yield() }

        await model.saveCheckIn(date: .now, mood: 6, libido: 6, energy: 6)
        #expect(model.saveError?.contains("already") == true)
        await #expect(throws: (any Error).self) { try await model.resetData() }
        await first.value
        #expect(await repository.checkInWrites == 1)
        #expect(!model.isBusy)
    }

    @Test func labLoadFailureRecoversAndEqualDatesHaveDeterministicIDOrdering() async {
        let repository = TestTrackingRepository()
        await repository.configure(failReads: true)
        let model = LabResultsViewModel(repository: repository)
        await model.load()
        #expect(model.message != nil)
        #expect(!model.isBusy)

        let date = Date(timeIntervalSince1970: 100)
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        await repository.seed(labResults: [
            LabResult(id: secondID, test: .e2, value: 2, unit: "pg/mL", recordedAt: date),
            LabResult(id: firstID, test: .e2, value: 1, unit: "pg/mL", recordedAt: date)
        ])
        await repository.configure()
        await model.load()
        #expect(model.results.map(\.id) == [firstID, secondID])
        #expect(model.message == nil)
    }

    @Test func labSuccessfulSaveCanReportRefreshFailureAndBusyCallsAreIgnored() async {
        let repository = TestTrackingRepository()
        await repository.configure(writeDelay: .milliseconds(100), failReadsAfterWrite: true)
        let model = LabResultsViewModel(repository: repository, locale: Locale(identifier: "en_US"))
        model.value = "12"
        let save = Task { await model.save() }
        while !model.isBusy { await Task.yield() }
        await model.save()
        await model.delete(LabResult(id: UUID(), test: .e2, value: 1, unit: "pg/mL", recordedAt: .now))
        await model.load()
        await save.value

        #expect(await repository.labWrites == 1)
        #expect(model.didSave)
        #expect(model.value.isEmpty)
        #expect(model.message?.contains("saved") == true)
        #expect(!model.isBusy)
    }

    @Test func calibrationPreferencePersistsAndCorruptPreferenceFallsBack() throws {
        let (defaults, name) = try settings()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("not json".utf8), forKey: "checkInReminderPreferences")
        defaults.set(Data("not json".utf8), forKey: "levelsNotificationPreferences")
        defaults.set(Data("not json".utf8), forKey: "regimenNotificationPreferences")

        #expect(CheckInReminderViewModel(settings: defaults, scheduler: TestCheckInReminderScheduler()).preferences
            == CheckInReminderPreferences())
        #expect(LevelsNotificationViewModel(settings: defaults, scheduler: TestLevelNotificationScheduler()).preferences
            == LevelsNotificationPreferences())
        #expect(RegimenNotificationViewModel(settings: defaults, scheduler: TestRegimenNotificationScheduler()).preferences
            == RegimenNotificationPreferences())

        let lab = LabResultsViewModel(repository: TestTrackingRepository(), settings: defaults)
        lab.useLatestE2ResultForCalibration = true
        #expect(LabResultsViewModel(repository: TestTrackingRepository(), settings: defaults)
            .useLatestE2ResultForCalibration)
    }

    @Test func changingLevelPreferencesDuringPredictionCannotScheduleStaleEvents() async throws {
        let (defaults, name) = try settings()
        defer { defaults.removePersistentDomain(forName: name) }
        let scheduler = TestLevelNotificationScheduler()
        let model = LevelsNotificationViewModel(
            settings: defaults,
            scheduler: scheduler,
            calculator: SlowNotificationPredictionCalculator()
        )
        model.preferences.enabled = true
        model.preferences.kinds = [.e2Peak]
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let regimen = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
                                  doseMilligramsOfEster: 2, route: .intramuscular,
                                  intervalHours: 24, effectiveFrom: now,
                                  effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let old = Task {
            await model.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        }
        await Task.yield()
        model.preferences.enabled = false
        await model.refresh(input: LevelsPredictionInput(regimen: regimen), now: now)
        await old.value

        #expect(scheduler.events.isEmpty)
        #expect(model.scheduledCount == 0)
    }

    @Test func invalidStoredCheckInReminderTimeFallsBackToDefaults() throws {
        let (defaults, name) = try settings()
        defer { defaults.removePersistentDomain(forName: name) }
        let invalid = CheckInReminderPreferences(enabled: true, hour: 24, minute: 60)
        defaults.set(try JSONEncoder().encode(invalid), forKey: "checkInReminderPreferences")
        #expect(CheckInReminderViewModel(settings: defaults, scheduler: TestCheckInReminderScheduler()).preferences
            == CheckInReminderPreferences())
    }
}
