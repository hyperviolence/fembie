import Foundation
import Testing
@testable import fembie

struct DataExportTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func exportContainsRegimensInjectionEventsAndCheckInsAsJSON() async throws {
        let regimenID = UUID()
        var regimen = try Regimen(
            id: regimenID,
            ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4,
            route: .intramuscular,
            intervalHours: 168,
            effectiveFrom: date,
            effectiveUntil: nil,
            timeZoneIdentifier: "UTC"
        )
        let event = InjectionEvent(
            id: UUID(),
            regimenID: regimenID,
            scheduledAt: date,
            doseMilligramsOfEster: 4,
            adjustment: .confirmed
        )
        regimen.injectionEvents = [event]
        let checkIn = CheckIn(id: UUID(), recordedAt: date, mood: 7, libido: 6, energy: 8)
        let repository = TestTrackingRepository(regimens: [regimen])
        try await repository.save(event)
        await repository.seed(checkIns: [checkIn])

        let file = try await DataExporter(repository: repository).makeFile()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(DataExport.self, from: file.data)

        #expect(export.regimens.map(\.id) == [regimen.id])
        #expect(export.regimens.first?.injectionEvents.map(\.id) == [event.id])
        #expect(export.injectionEvents.map(\.id) == [event.id])
        #expect(export.checkIns.map(\.id) == [checkIn.id])
    }

    @Test func exportProducesReadablePrettyPrintedJSONWithEmptyCollections() async throws {
        let file = try await DataExporter(repository: TestTrackingRepository()).makeFile()
        let object = try #require(JSONSerialization.jsonObject(with: file.data) as? [String: Any])

        #expect((object["regimens"] as? [Any])?.isEmpty == true)
        #expect((object["injectionEvents"] as? [Any])?.isEmpty == true)
        #expect((object["checkIns"] as? [Any])?.isEmpty == true)
        #expect(String(decoding: file.data, as: UTF8.self).contains("\n"))
    }

    @Test func exportedFilenameIncludesDateAndTime() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let file = try await DataExporter(repository: TestTrackingRepository()).makeFile(
            exportedAt: date,
            calendar: calendar
        )

        #expect(file.fileName == "fembie-data-exported-2023-11-14-22-13-20.json")
    }

    @Test func exportPropagatesRepositoryReadFailures() async {
        let repository = TestTrackingRepository()
        await repository.configure(failReads: true)

        await #expect(throws: (any Error).self) {
            try await DataExporter(repository: repository).makeFile()
        }
    }
}
