import Foundation
import Testing
@testable import fembie

struct DataImportTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func importsValidatedDataAndReplacesExistingValues() async throws {
        let source = TestTrackingRepository(regimens: [try regimen()])
        let regimen = try #require(await source.regimens().first)
        let event = InjectionEvent(
            id: UUID(),
            regimenID: regimen.id,
            scheduledAt: date,
            doseMilligramsOfEster: 4,
            adjustment: .confirmed
        )
        var regimenWithEvent = regimen
        regimenWithEvent.injectionEvents = [event]
        try await source.save(regimenWithEvent)
        try await source.save(event)
        await source.seed(checkIns: [CheckIn(id: UUID(), recordedAt: date, mood: 5, libido: 6, energy: 7)])
        let data = try await DataExporter(repository: source).makeFile(appVersion: "1.2.3").data
        let destination = TestTrackingRepository()

        try await DataImporter(repository: destination).importData(data)

        let importedRegimens = try await destination.regimens()
        let importedEvents = try await destination.injectionEvents()
        let importedCheckIns = try await destination.checkIns()
        #expect(importedRegimens.map(\.id) == [regimen.id])
        #expect(importedEvents.map(\.id) == [event.id])
        #expect(importedCheckIns.count == 1)
    }

    @Test func acceptsVersionOneWithEventsStoredOnlyInsideRegimen() async throws {
        let regimenID = UUID()
        var value = try regimen(id: regimenID)
        value.injectionEvents = [
            InjectionEvent(
                id: UUID(),
                regimenID: regimenID,
                scheduledAt: date,
                doseMilligramsOfEster: 4,
                adjustment: .confirmed
            )
        ]
        let export = DataExport(regimens: [value], injectionEvents: [], checkIns: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoded = try DataImportValidator().decodeAndValidate(encoder.encode(export))

        #expect(decoded.regimens.first?.injectionEvents.count == 1)
        #expect(decoded.injectionEvents.isEmpty)
    }

    @Test func acceptsLegacyVersionOneWithoutMetadata() async throws {
        let legacy = """
        {"regimens":[],"injectionEvents":[],"checkIns":[]}
        """.data(using: .utf8) ?? Data()

        let export = try DataImportValidator().decodeAndValidate(legacy)

        #expect(export.formatVersion == 1)
        #expect(export.appVersion == nil)
    }

    @Test func acceptsLegacyVersionOneWithSingularRegimen() async throws {
        let regimen = try regimen()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let regimenObject = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(regimen)) as? [String: Any]
        )
        let legacyObject: [String: Any] = [
            "regimen": regimenObject,
            "injectionEvents": [],
            "checkIns": []
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyObject)

        let export = try DataImportValidator().decodeAndValidate(data)

        #expect(export.formatVersion == 1)
        #expect(export.regimens.map(\.id) == [regimen.id])
    }

    @Test func acceptsLegacyVersionOneWithNoRegimen() throws {
        let legacy = """
        {"regimen":null,"injectionEvents":[],"checkIns":[]}
        """.data(using: .utf8) ?? Data()

        let export = try DataImportValidator().decodeAndValidate(legacy)

        #expect(export.regimens.isEmpty)
    }

    @Test func rejectsAmbiguousSingularAndPluralRegimens() throws {
        let ambiguous = """
        {"regimen":null,"regimens":[],"injectionEvents":[],"checkIns":[]}
        """.data(using: .utf8) ?? Data()

        #expect(throws: DataImportError.invalidJSON) {
            try DataImportValidator().decodeAndValidate(ambiguous)
        }
    }

    @Test func rejectsUnknownFields() {
        let data = """
        {"formatVersion":1,"regimens":[],"injectionEvents":[],"checkIns":[],"script":"payload"}
        """.data(using: .utf8) ?? Data()

        #expect(throws: DataImportError.unexpectedField("script")) {
            try DataImportValidator().decodeAndValidate(data)
        }
    }

    @Test func rejectsFutureFormatVersions() {
        let data = """
        {"formatVersion":2,"regimens":[],"injectionEvents":[],"checkIns":[]}
        """.data(using: .utf8) ?? Data()

        #expect(throws: DataImportError.unsupportedFormatVersion(2)) {
            try DataImportValidator().decodeAndValidate(data)
        }
    }

    @Test func rejectsInvalidDomainValuesWithoutWriting() async throws {
        let destination = TestTrackingRepository(regimens: [try regimen()])
        let originalID = try #require(await destination.regimens().first?.id)
        let data = """
        {
          "formatVersion": 1,
          "regimens": [],
          "injectionEvents": [],
          "checkIns": [{
            "id": "00000000-0000-0000-0000-000000000001",
            "recordedAt": "2023-11-14T22:13:20Z",
            "mood": 99,
            "libido": 5,
            "energy": 5
          }]
        }
        """.data(using: .utf8) ?? Data()

        await #expect(throws: DataImportError.invalidValue) {
            try await DataImporter(repository: destination).importData(data)
        }
        let retainedRegimens = try await destination.regimens()
        #expect(retainedRegimens.map(\.id) == [originalID])
    }

    @Test func exportIncludesFormatAndAppVersions() async throws {
        let file = try await DataExporter(repository: TestTrackingRepository()).makeFile(appVersion: "9.8.7")
        let object = try #require(JSONSerialization.jsonObject(with: file.data) as? [String: Any])

        #expect(object["formatVersion"] as? Int == 1)
        #expect(object["appVersion"] as? String == "9.8.7")
    }

    private func regimen(id: UUID = UUID()) throws -> Regimen {
        try Regimen(
            id: id,
            ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4,
            route: .intramuscular,
            intervalHours: 168,
            effectiveFrom: date,
            effectiveUntil: nil,
            timeZoneIdentifier: "UTC"
        )
    }
}
