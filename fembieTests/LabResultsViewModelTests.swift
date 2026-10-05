import Foundation
import Testing
@testable import fembie

@MainActor
struct LabResultsViewModelTests {
    @Test func allTestTypesPersistWithValuesUnitsAndTimestamps() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LabResultsTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = LabResultsViewModel(repository: FileTrackingRepository(baseURL: directory),
                                        locale: Locale(identifier: "en_US"))
        let date = Date(timeIntervalSince1970: 1_700_000_000.125)
        for test in LabTest.allCases {
            model.test = test
            model.value = "12.5"
            model.recordedAt = date
            await model.save()
            #expect(model.didSave)
            #expect(model.message == nil)
        }
        let saved = try await FileTrackingRepository(baseURL: directory).labResults()
        #expect(saved.count == 4)
        #expect(Set(saved.map(\.test)) == Set(LabTest.allCases))
        #expect(saved.allSatisfy { $0.value == 12.5 && $0.unit == $0.test.unit && $0.recordedAt == date })
    }

    @Test func newestResultsAppearFirstAndExpandThreeAtATime() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LabResultsTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        for index in 0..<8 {
            try await repository.save(LabResult(id: UUID(), test: .e2, value: Double(index),
                                               recordedAt: Date(timeIntervalSince1970: Double(index))))
        }
        let model = LabResultsViewModel(repository: repository)
        await model.load()
        #expect(model.visibleResults.map(\.value) == [7, 6, 5])
        #expect(model.hasMoreResults)
        model.showMore()
        #expect(model.visibleResults.map(\.value) == [7, 6, 5, 4, 3, 2])
        model.showMore()
        #expect(model.visibleResults.count == 8)
        #expect(!model.hasMoreResults)
        model.showMore()
        #expect(model.visibleResults.count == 8)
    }

    @Test func invalidValuesDoNotWriteResults() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LabResultsTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let model = LabResultsViewModel(repository: repository, locale: Locale(identifier: "en_US"))
        for input in ["", "abc", "-1", "NaN", "infinity"] {
            model.value = input
            await model.save()
            #expect(!model.didSave)
            #expect(model.message != nil)
        }
        #expect(try await repository.labResults().isEmpty)
        await #expect(throws: (any Error).self) {
            try await repository.save(LabResult(id: UUID(), test: .e2, value: .infinity, recordedAt: .now))
        }
    }

    @Test func localeDecimalSeparatorAndNewSaveRefreshTheList() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LabResultsTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = LabResultsViewModel(repository: FileTrackingRepository(baseURL: directory),
                                        locale: Locale(identifier: "tr_TR"))
        model.value = "12,5"
        model.test = .shbg
        await model.save()
        #expect(model.visibleResults.first?.value == 12.5)
        #expect(model.visibleResults.first?.test == .shbg)
        #expect(model.value.isEmpty)
        #expect(model.didSave)
    }

    @Test func failedSavePreservesHistoryAndFormInput() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LabResultsTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let first = LabResult(id: UUID(), test: .lh, value: 5, recordedAt: .now)
        try await repository.save(first)
        let model = LabResultsViewModel(repository: repository, locale: Locale(identifier: "en_US"))
        await model.load()
        let file = directory.appending(path: "labResults.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        model.value = "10"
        await model.save()
        #expect(model.results.map(\.id) == [first.id])
        #expect(model.value == "10")
        #expect(!model.didSave)
        #expect(model.message != nil)
        #expect(!model.isBusy)
        #expect(try await repository.labResults().count == 1)
    }

    @Test func selectingATestAutomaticallySelectsItsFixedUnit() {
        let model = LabResultsViewModel(repository: FileTrackingRepository())
        let expected: [(LabTest, String)] = [(.e2, "pg/mL"), (.testosterone, "ng/dL"),
                                           (.lh, "mIU/mL"), (.shbg, "nmol/L")]
        for (test, unit) in expected {
            model.test = test
            #expect(model.unit == unit)
            let result = LabResult(id: UUID(), test: test, value: 10, recordedAt: .now)
            #expect(result.unit == unit)
        }
    }

    @Test func historicalUnitsArePreservedWhenNewResultsAreSaved() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LabResultsTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let historical = Data("""
        [{"id":"00000000-0000-0000-0000-000000000001","test":"Testosterone","value":2.5,"unit":"nmol/L","recordedAt":1234}]
        """.utf8)
        try historical.write(to: directory.appending(path: "labResults.json"))
        let model = LabResultsViewModel(repository: FileTrackingRepository(baseURL: directory),
                                        locale: Locale(identifier: "en_US"))
        await model.load()
        #expect(model.results.first?.unit == "nmol/L")
        #expect(model.results.first?.value == 2.5)
        model.test = .testosterone
        model.value = "20"
        await model.save()
        let stored = try await FileTrackingRepository(baseURL: directory).labResults()
        #expect(stored.contains { $0.value == 2.5 && $0.unit == "nmol/L" })
        #expect(stored.contains { $0.value == 20 && $0.unit == "ng/dL" })
    }
}
