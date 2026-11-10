import Foundation
import Testing
@testable import fembie

@MainActor
struct RegimenColorTests {
    @Test(arguments: RegimenColor.allCases)
    func colorSurvivesStorageExportImportAndSync(_ color: RegimenColor) async throws {
        let directory = URL.temporaryDirectory.appending(path: "RegimenColor-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let regimen = try Regimen(id: UUID(), ester: EstradiolType.estradiolEnanthate.displayName,
                                  doseMilligramsOfEster: 5, route: .intramuscular, intervalHours: 168,
                                  effectiveFrom: .now, effectiveUntil: nil, timeZoneIdentifier: "UTC", color: color)
        try await repository.save(regimen)
        let reloaded = FileTrackingRepository(baseURL: directory)
        #expect(try await reloaded.regimens().first?.color == color)
        let export = try await DataExporter(repository: repository).makeFile()
        let decoded = try DataImportValidator().decodeAndValidate(export.data)
        #expect(decoded.regimens.first?.color == color)
        let destination = FileTrackingRepository(baseURL: directory.appending(path: "imported"))
        try await DataImporter(repository: destination).importData(export.data)
        #expect(try await destination.regimens().first?.color == color)
        let snapshot = try await repository.syncSnapshot()
        try snapshot.validate()
        #expect(try snapshot.values(Regimen.self, prefix: "regimen/").first?.color == color)
    }

    @Test func legacyJSONWithoutColorRemainsReadableAndImportable() throws {
        let regimen = try Regimen(id: UUID(), ester: "Estradiol Enanthate",
                                  doseMilligramsOfEster: 5, route: .intramuscular, intervalHours: 168,
                                  effectiveFrom: .now, effectiveUntil: nil, timeZoneIdentifier: "UTC")
        let localData = try JSONEncoder().encode(regimen)
        let localObject = try #require(JSONSerialization.jsonObject(with: localData) as? [String: Any])
        #expect(localObject["color"] == nil)
        #expect(try JSONDecoder().decode(Regimen.self, from: localData).color == nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(DataExport(regimens: [regimen], injectionEvents: [], checkIns: []))
        #expect(try DataImportValidator().decodeAndValidate(data).regimens.first?.color == nil)

        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let regimens = try #require(object.removeValue(forKey: "regimens") as? [[String: Any]])
        object["regimen"] = regimens.first
        let legacy = try JSONSerialization.data(withJSONObject: object)
        #expect(try DataImportValidator().decodeAndValidate(legacy).regimens.first?.color == nil)
    }

    @Test func editingColorPreservesEventsAndCanRestoreDefault() async throws {
        let directory = URL.temporaryDirectory.appending(path: "RegimenColor-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let now = Date()
        let model = RegimenViewModel(repository: repository, locale: Locale(identifier: "en_US"), clock: { now })
        model.beginAddingRegimen()
        model.dose = "5"
        model.interval = "7"
        model.selectedColor = .teal
        #expect(await model.saveRegimen())
        let saved = try #require(model.regimens.first)
        let event = try #require(saved.injectionEvents.first)
        await model.setAdjustment(eventID: event.id, to: .skipped)
        model.beginEditing(try #require(model.regimens.first))
        #expect(model.selectedColor == .teal)
        model.selectedColor = .purple
        #expect(await model.saveRegimen())
        #expect(model.regimens.first?.color == .purple)
        #expect(model.regimens.first?.injectionEvents.map(\.id) == saved.injectionEvents.map(\.id))
        #expect(model.regimens.first?.injectionEvents.first?.adjustment == .skipped)
        model.selectedColor = nil
        #expect(await model.saveRegimen())
        #expect(try await repository.regimens().first?.color == nil)
        model.selectedColor = .red
        model.beginAddingRegimen()
        #expect(model.selectedColor == nil)
    }
}
