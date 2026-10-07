import Foundation
import Testing
@testable import fembie

@MainActor
struct InjectionAdjustmentRegressionTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen() throws -> Regimen {
        let draft = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 168,
            effectiveFrom: now.addingTimeInterval(-14 * 86400), effectiveUntil: nil,
            timeZoneIdentifier: "UTC")
        return try InjectionSchedule().extending(draft, through: now.addingTimeInterval(30 * 86400))
    }

    @Test func movingInjectionIntoPastPreservesRecurrenceAndPredictionAfterReload() async throws {
        let directory = URL.temporaryDirectory.appending(path: "InjectionAdjustmentTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        try await repository.save(regimen())
        let currentTime = now
        let model = RegimenViewModel(repository: repository, clock: { currentTime })
        await model.load()
        let event = try #require(model.savedRegimen?.injectionEvents.first { $0.scheduledAt > currentTime })
        let actualAt = now.addingTimeInterval(-3600)
        await model.setAdjustment(eventID: event.id, to: .moved(actualAt: actualAt))
        let adjusted = try #require(model.savedRegimen?.injectionEvents.first { $0.id == event.id })
        #expect(adjusted.scheduledAt == event.scheduledAt)
        #expect(adjusted.adjustment == .moved(actualAt: actualAt))
        #expect(InjectionStatus(event: adjusted, now: now) == .confirmed)
        // Confirming an already moved past injection must not lose its actual time.
        await model.setAdjustment(eventID: event.id, to: .confirmed)
        let restored = RegimenViewModel(repository: FileTrackingRepository(baseURL: directory), clock: { currentTime })
        await restored.load()
        #expect(restored.loadError == nil)
        let saved = try #require(restored.savedRegimen)
        #expect(saved.injectionEvents.first { $0.id == event.id }?.adjustment == .moved(actualAt: actualAt))
        _ = try await LevelsPredictionCalculator().predict(regimen: saved, now: now)
    }

    @Test func loadingRepairsAndPersistsConfirmedDatesOverwrittenByEarlierEdit() async throws {
        let directory = URL.temporaryDirectory.appending(path: "InjectionAdjustmentTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        var broken = try regimen()
        let original = broken.injectionEvents[2]
        let actualAt = original.scheduledAt.addingTimeInterval(-3600)
        broken.injectionEvents[2] = InjectionEvent(id: original.id, regimenID: original.regimenID,
            scheduledAt: actualAt, doseMilligramsOfEster: original.doseMilligramsOfEster, adjustment: .confirmed)
        try await repository.save(broken)
        #expect(throws: RegimenValidationError.self) {
            try InjectionSchedule().extending(broken, through: now)
        }
        let currentTime = now
        let model = RegimenViewModel(repository: repository, clock: { currentTime })
        await model.load()
        #expect(model.loadError == nil)
        let repaired = try #require(model.savedRegimen?.injectionEvents.first { $0.id == original.id })
        #expect(repaired.scheduledAt == original.scheduledAt)
        #expect(repaired.adjustment == .moved(actualAt: actualAt))
        let reloaded = try #require(try await FileTrackingRepository(baseURL: directory).regimens().first)
        #expect(reloaded.injectionEvents.first { $0.id == original.id }?.scheduledAt == original.scheduledAt)
        #expect(reloaded.injectionEvents.first { $0.id == original.id }?.adjustment == .moved(actualAt: actualAt))
    }

    @Test func repairLeavesValidOverridesAloneAndRejectsAmbiguousArrayOrder() throws {
        var input = try regimen()
        input.injectionEvents[0].adjustment = .moved(actualAt: now.addingTimeInterval(-1000))
        #expect(RegimenScheduleRepair.restoringScheduledDates(in: input) == nil)
        input.injectionEvents.swapAt(0, 1)
        #expect(RegimenScheduleRepair.restoringScheduledDates(in: input) == nil)
    }
}
