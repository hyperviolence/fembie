import Foundation
import Testing
@testable import fembie

@MainActor
struct CustomWellbeingMetricTests {
    @Test func deletionRemovesOnlySelectedMetricAndSurvivesReload() async throws {
        let directory = URL.temporaryDirectory.appending(path: "MetricDeletion-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let model = CheckInViewModel(repository: repository)
        model.addCustomMetric(label: "Sleep", lowLabel: "Poor", highLabel: "Restful")
        model.addCustomMetric(label: "Stress", lowLabel: "None", highLabel: "High")
        let removedID = try #require(model.customRatings.first?.id)
        await model.saveCheckIn(date: .now, mood: 3, libido: 4, energy: 5)
        await model.saveCheckIn(date: .now, mood: 6, libido: 7, energy: 8)
        await model.deleteCustomMetric(id: removedID)
        #expect(model.metricDeletionError == nil)
        #expect(model.customRatings.map(\.label) == ["Stress"])
        #expect(model.checkIns.count == 2)
        #expect(model.checkIns.allSatisfy { $0.customRatings.map(\.label) == ["Stress"] })
        #expect(CustomWellbeingChartSeries.make(from: model.checkIns).map(\.label) == ["Stress"])
        let reloaded = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        await reloaded.loadCheckIns()
        #expect(reloaded.customRatings.map(\.label) == ["Stress"])
        #expect(reloaded.checkIns.map(\.mood) == [3, 6])
        let snapshot = try await repository.syncSnapshot()
        let synced = try snapshot.values(CheckIn.self, prefix: "checkIn/")
        #expect(synced.allSatisfy { $0.customRatings.map(\.label) == ["Stress"] })
    }

    @Test func failedDeletionKeepsMetricAndSavedValues() async throws {
        let directory = URL.temporaryDirectory.appending(path: "MetricDeletion-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        model.addCustomMetric(label: "Sleep", lowLabel: "Poor", highLabel: "Restful")
        await model.saveCheckIn(date: .now, mood: 3, libido: 4, energy: 5)
        let metric = try #require(model.customRatings.first)
        let store = directory.appending(path: "checkIns.json")
        try FileManager.default.removeItem(at: store)
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        await model.deleteCustomMetric(id: metric.id)
        #expect(model.metricDeletionError != nil)
        #expect(model.customRatings == [metric])
        #expect(model.checkIns.first?.customRatings == [metric])
        #expect(!model.isBusy)
    }

    @Test func unsavedMetricCanBeDeleted() async throws {
        let directory = URL.temporaryDirectory.appending(path: "MetricDeletion-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        model.addCustomMetric(label: "Sleep", lowLabel: "Poor", highLabel: "Restful")
        let id = try #require(model.customRatings.first?.id)
        await model.deleteCustomMetric(id: id)
        #expect(model.customRatings.isEmpty)
        #expect(model.checkIns.isEmpty)
    }

    @Test func addingTrimsLabelsAndRejectsDuplicates() async {
        let directory = URL.temporaryDirectory.appending(path: "CustomMetrics-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        #expect(model.addCustomMetric(label: " Sleep quality ", lowLabel: " Poor ", highLabel: " Restful "))
        #expect(model.customRatings.first?.label == "Sleep quality")
        #expect(model.customRatings.first?.lowLabel == "Poor")
        #expect(model.customRatings.first?.highLabel == "Restful")
        #expect(!model.addCustomMetric(label: "SLEEP QUALITY", lowLabel: "Low", highLabel: "High"))
        #expect(!model.addCustomMetric(label: "mood", lowLabel: "Low", highLabel: "High"))
        #expect(model.customRatings.count == 1)
        #expect(model.metricError != nil)
    }

    @Test(arguments: ["", " \n ", String(repeating: "a", count: 101)])
    func invalidLabelsAreRejected(_ invalid: String) async {
        let directory = URL.temporaryDirectory.appending(path: "CustomMetrics-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        #expect(!model.addCustomMetric(label: invalid, lowLabel: "Low", highLabel: "High"))
        #expect(!model.addCustomMetric(label: "Sleep", lowLabel: invalid, highLabel: "High"))
        #expect(!model.addCustomMetric(label: "Sleep", lowLabel: "Low", highLabel: invalid))
        #expect(model.customRatings.isEmpty)
    }

    @Test func oldCheckInsDecodeWithoutCustomRatings() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","recordedAt":0,"mood":5,"libido":5,"energy":5}
        """
        let checkIn = try JSONDecoder().decode(CheckIn.self, from: Data(json.utf8))
        #expect(checkIn.customRatings.isEmpty)
        try checkIn.validate()
    }

    @Test(arguments: [-1.0, 11.0, Double.infinity, Double.nan])
    func invalidRatingsAreRejected(_ value: Double) {
        let rating = CustomWellbeingRating(id: UUID(), label: "Sleep", lowLabel: "Poor",
                                          highLabel: "Restful", value: value)
        #expect(throws: TrackingValidationError.self) { try rating.validate() }
    }

    @Test func duplicateMetricIdentifiersAreRejected() {
        let rating = CustomWellbeingRating(id: UUID(), label: "Sleep", lowLabel: "Poor",
                                          highLabel: "Restful", value: 5)
        let checkIn = CheckIn(id: UUID(), recordedAt: .now, mood: 5, libido: 5, energy: 5,
                              customRatings: [rating, rating])
        #expect(throws: TrackingValidationError.self) { try checkIn.validate() }
    }

    @Test func customMetricsSurviveDiskExportImportAndSync() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CustomMetrics-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let model = CheckInViewModel(repository: repository)
        #expect(model.addCustomMetric(label: "Sleep", lowLabel: "Poor", highLabel: "Restful"))
        model.customRatings[0].value = 8
        await model.saveCheckIn(date: .now, mood: 5, libido: 5, energy: 5)
        #expect(model.saveError == nil)
        let reloaded = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        await reloaded.loadCheckIns()
        #expect(reloaded.customRatings == model.customRatings)

        let file = try await DataExporter(repository: repository).makeFile()
        let imported = try DataImportValidator().decodeAndValidate(file.data)
        #expect(imported.checkIns.first?.customRatings == model.customRatings)
        let destination = FileTrackingRepository(baseURL: directory.appending(path: "imported"))
        try await DataImporter(repository: destination).importData(file.data)
        #expect(try await destination.checkIns().first?.customRatings == model.customRatings)

        let snapshot = try await repository.syncSnapshot()
        try snapshot.validate()
        let decoded = try JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(snapshot))
        let synced = try decoded.values(CheckIn.self, prefix: "checkIn/")
        #expect(synced.first?.customRatings == model.customRatings)
        try await model.resetData()
        #expect(model.customRatings.isEmpty)
        #expect(try await repository.checkIns().isEmpty)
    }

    @Test func averagesExcludeMissingRatingsAndKeepMetricIdentity() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CustomMetrics-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        var rating = CustomWellbeingRating(id: UUID(), label: "Sleep", lowLabel: "Poor",
                                          highLabel: "Restful", value: 2)
        try await repository.save(CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 100),
                                         mood: 5, libido: 5, energy: 5, customRatings: [rating]))
        rating.value = 8
        try await repository.save(CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 200),
                                         mood: 5, libido: 5, energy: 5, customRatings: [rating]))
        try await repository.save(CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 300),
                                         mood: 5, libido: 5, energy: 5))
        let model = CheckInViewModel(repository: repository)
        await model.loadCheckIns()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let average = try #require(model.dailyAverages(calendar: calendar).first?.customRatings.first)
        #expect(average.id == rating.id)
        #expect(average.value == 5)
        #expect(model.customRatings == [rating])

        try await repository.replaceTrackingData(regimens: [], injectionEvents: [], checkIns: [])
        await model.reloadCheckIns()
        #expect(model.customRatings.isEmpty)
    }

    @Test func invalidCustomRatingDoesNotSave() async {
        let directory = URL.temporaryDirectory.appending(path: "CustomMetrics-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let model = CheckInViewModel(repository: repository)
        model.addCustomMetric(label: "Sleep", lowLabel: "Poor", highLabel: "Restful")
        model.customRatings[0].value = 11
        await model.saveCheckIn(date: .now, mood: 5, libido: 5, energy: 5)
        #expect(model.saveError != nil)
        #expect(model.lastSavedCheckInDate == nil)
    }
}
