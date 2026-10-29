import Foundation
import Testing
@testable import fembie

@MainActor
struct RegimenViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func model(repository: TestTrackingRepository, locale: Locale = Locale(identifier: "en_US")) -> RegimenViewModel {
        let now = now
        let model = RegimenViewModel(repository: repository, locale: locale, clock: { now })
        model.dose = "2"
        model.interval = "7"
        return model
    }

    @Test func intervalUnitSwitchConvertsValueAndSavesHours() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        #expect(model.intervalUnit == .days)
        model.intervalUnit = .hours
        #expect(model.interval == "168")
        model.interval = "36"
        await model.saveRegimen()
        #expect(model.savedRegimen?.intervalHours == 36)
        model.intervalUnit = .days
        #expect(model.interval == "1.5")
        await model.saveRegimen()
        #expect(model.savedRegimen?.intervalHours == 36)
        model.intervalUnit = .hours
        #expect(model.interval == "36")
        try await model.resetData()
        #expect(model.intervalUnit == .days)
        #expect(model.interval.isEmpty)
    }

    @Test func intervalConversionSupportsLocalizedFractionsAndInvalidInput() async throws {
        let model = model(repository: TestTrackingRepository(), locale: Locale(identifier: "tr_TR"))
        model.interval = "3,5"
        model.intervalUnit = .hours
        #expect(model.interval == "84")
        model.interval = "5,5"
        model.intervalUnit = .days
        #expect(model.interval.contains(","))
        await model.saveRegimen()
        let saved = try #require(model.savedRegimen)
        #expect(abs(saved.intervalHours - 5.5) < 1e-10)
        model.interval = "invalid"
        model.intervalUnit = .hours
        #expect(model.interval == "invalid")
        #expect(model.validationMessage != nil)
        model.interval = ""
        model.intervalUnit = .days
        #expect(model.interval.isEmpty)
    }

    @Test func localizedInputAndFullValidation() async {
        let model = model(repository: TestTrackingRepository(), locale: Locale(identifier: "tr_TR"))
        await model.load()
        model.dose = "2,5"
        model.interval = "3,5"
        #expect(model.canSave)
        await model.saveRegimen()
        #expect(model.savedRegimen?.doseMilligramsOfEster == 2.5)
        #expect(model.savedRegimen?.intervalHours == 84)
        let savedID = model.savedRegimen?.id
        for invalid in ["", "0", "-1", "nan", "inf", "2,5junk", "1,2,3", "1.000"] {
            model.dose = invalid
            #expect(model.validationMessage != nil)
            await model.saveRegimen()
            #expect(model.savedRegimen?.id == savedID)
        }
        model.dose = "2"
        model.interval = "0,000001"
        #expect(model.validationMessage != nil)
        await model.saveRegimen()
        #expect(model.savedRegimen?.id == savedID)
    }

    @Test func overlappingRegimensCanBeAddedReloadedAndEdited() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await model.saveRegimen()
        let originalID = model.savedRegimen?.id
        model.beginAddingRegimen()
        model.dose = "3"
        model.interval = "1"
        model.firstInjection = now.addingTimeInterval(86400)
        model.hasEffectiveUntil = true
        model.effectiveUntil = now.addingTimeInterval(10 * 86400)
        await model.saveRegimen()
        let replacementID = model.savedRegimen?.id
        #expect(replacementID != originalID)
        await model.load()
        #expect(model.savedRegimen?.id == replacementID)
        #expect(model.regimenTitle == "Upcoming regimen")
        #expect(try await repository.regimens().count == 2)
        let original = try #require(model.regimens.first { $0.id == originalID })
        model.beginEditing(original)
        model.hasEffectiveUntil = true
        model.effectiveUntil = now.addingTimeInterval(5 * 86400)
        await model.saveRegimen()
        #expect(model.regimens.count == 2)
        #expect(model.regimens.first { $0.id == originalID }?.effectiveUntil == model.effectiveUntil)
    }

    @Test func failedAdjustmentPreservesStatusAndRetryWorks() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await model.saveRegimen()
        let event = try #require(model.savedRegimen?.injectionEvents.first)
        await repository.configure(failWrites: true)
        await model.setAdjustment(eventID: event.id, to: .skipped)
        #expect(model.savedRegimen?.injectionEvents.first?.adjustment == InjectionAdjustment.none)
        #expect(model.showAlert)
        await repository.configure()
        await model.setAdjustment(eventID: event.id, to: .skipped)
        #expect(model.savedRegimen?.injectionEvents.first?.adjustment == .skipped)
        await model.setAdjustment(eventID: event.id, to: .none)
        #expect(model.savedRegimen?.injectionEvents.first?.adjustment == InjectionAdjustment.none)
    }

    @Test func deletionUpdatesListAndFailedDeletionPreservesIt() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await model.saveRegimen()
        let regimen = try #require(model.savedRegimen)

        await repository.configure(failWrites: true)
        await model.deleteRegimen(regimen)
        #expect(model.regimens.map(\.id) == [regimen.id])
        #expect(model.showAlert)

        await repository.configure()
        await model.deleteRegimen(regimen)
        #expect(model.regimens.isEmpty)
        #expect(try await repository.regimens().isEmpty)
    }

    @Test func failedReplacementPreservesPreviousRegimen() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await model.saveRegimen()
        let originalID = model.savedRegimen?.id
        model.dose = "3"
        await repository.configure(failWrites: true)
        await model.saveRegimen()
        #expect(model.savedRegimen?.id == originalID)
        #expect(model.savedRegimen?.doseMilligramsOfEster == 2)
        #expect(try await repository.regimens().first?.id == originalID)
    }

    @Test func timeRefreshChangesUpcomingToAssumedTaken() async throws {
        let repository = TestTrackingRepository()
        var date = now
        let model = RegimenViewModel(repository: repository, locale: Locale(identifier: "en_US"), clock: { date })
        model.dose = "2"
        model.interval = "7"
        model.firstInjection = now.addingTimeInterval(60)
        await model.load()
        await model.saveRegimen()
        let event = try #require(model.visibleEvents.first)
        #expect(InjectionStatus(event: event, now: model.now).title == "Upcoming")
        date = now.addingTimeInterval(60)
        model.refreshTime()
        #expect(model.regimenTitle == "Current regimen")
        #expect(InjectionStatus(event: event, now: model.now).title == "Assumed taken")
    }

    @Test func paginationExtendsSavedScheduleWithoutLosingOverrides() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await model.saveRegimen()
        let original = try #require(model.savedRegimen?.injectionEvents.first)
        await model.setAdjustment(eventID: original.id, to: .skipped)
        let oldCount = model.savedRegimen?.injectionEvents.count ?? 0
        for _ in 0..<20 { await model.showMoreFuture() }
        #expect((model.savedRegimen?.injectionEvents.count ?? 0) > oldCount)
        #expect(model.savedRegimen?.injectionEvents.first?.id == original.id)
        #expect(model.savedRegimen?.injectionEvents.first?.adjustment == .skipped)
        #expect(try await repository.regimens().first?.injectionEvents.count == model.savedRegimen?.injectionEvents.count)
    }

    @Test func failedLoadAllowsSavingReplacement() async {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await repository.configure(failReads: true)
        await model.load()
        #expect(model.loadError != nil)
        #expect(!model.hasLoaded)
        #expect(model.canSave)
        await model.saveRegimen()
        #expect(await repository.writes == 1)
        #expect(model.loadError == nil)
        #expect(model.hasLoaded)
        #expect(model.savedRegimen != nil)
        #expect(model.canSave)
    }

    @Test func failedReplacementAfterLoadErrorKeepsError() async {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await repository.configure(failReads: true, failWrites: true)
        await model.load()
        let loadError = model.loadError
        await model.saveRegimen()
        #expect(model.loadError == loadError)
        #expect(!model.hasLoaded)
        #expect(model.savedRegimen == nil)
        #expect(model.showAlert)
        #expect(model.canSave)
    }

    @Test func concurrentSaveIsIgnoredWhileFirstIsPending() async {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await repository.configure(writeDelay: .milliseconds(50))
        let first = Task { await model.saveRegimen() }
        while !model.isBusy { await Task.yield() }
        #expect(!model.canSave)
        await model.saveRegimen()
        await first.value
        #expect(await repository.writes == 1)
    }

    @Test func paginationAndFutureConfirmation() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        model.firstInjection = now.addingTimeInterval(-30 * 86400)
        await model.load()
        await model.saveRegimen()
        #expect(model.visibleEvents.count == 3)
        #expect(model.hasMorePast)
        model.showMorePast()
        #expect(!model.hasMorePast)
        let future = try #require(model.savedRegimen?.injectionEvents.first(where: { $0.scheduledAt > now }))
        let writes = await repository.writes
        await model.setAdjustment(eventID: future.id, to: .confirmed)
        #expect(await repository.writes == writes + 1)
        let taken = try #require(model.savedRegimen?.injectionEvents.first { $0.id == future.id })
        #expect(taken.scheduledAt == future.scheduledAt)
        #expect(taken.adjustment == .moved(actualAt: now))
        #expect(InjectionStatus(event: taken, now: now) == .confirmed)
        await model.showMoreFuture()
        #expect(model.visibleEvents.count == 9)
    }
}
