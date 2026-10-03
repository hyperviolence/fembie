import Foundation
import Testing
@testable import FemmeTrack

@MainActor
struct RegimenViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func model(repository: TestTrackingRepository, locale: Locale = Locale(identifier: "en_US")) -> RegimenViewModel {
        let now = now
        let model = RegimenViewModel(repository: repository, locale: locale, clock: { now })
        model.dose = "2"
        model.intervalDays = "7"
        return model
    }

    @Test func localizedInputAndFullValidation() async {
        let model = model(repository: TestTrackingRepository(), locale: Locale(identifier: "tr_TR"))
        await model.load()
        model.dose = "2,5"
        model.intervalDays = "3,5"
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
        model.intervalDays = "0,000001"
        #expect(model.validationMessage != nil)
        await model.saveRegimen()
        #expect(model.savedRegimen?.id == savedID)
    }

    @Test func futureRegimenRemainsVisibleAfterReloadAndOverwrite() async throws {
        let repository = TestTrackingRepository()
        let model = model(repository: repository)
        await model.load()
        await model.saveRegimen()
        let originalID = model.savedRegimen?.id
        model.firstInjection = now.addingTimeInterval(86400)
        await model.saveRegimen()
        let replacementID = model.savedRegimen?.id
        #expect(replacementID != originalID)
        await model.load()
        #expect(model.savedRegimen?.id == replacementID)
        #expect(model.regimenTitle == "Upcoming regimen")
        #expect(try await repository.regimens().count == 1)
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
        model.intervalDays = "7"
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
        #expect(await repository.writes == writes)
        await model.showMoreFuture()
        #expect(model.visibleEvents.count == 9)
    }
}
