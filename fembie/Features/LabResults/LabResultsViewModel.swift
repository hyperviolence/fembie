import Foundation
import Observation

@MainActor
@Observable
final class LabResultsViewModel {
    var useLatestE2ResultForCalibration = false {
        didSet {
            settings.set(useLatestE2ResultForCalibration, forKey: "useLatestE2ResultForLevelsCalibration")
        }
    }
    var test: LabTest = .e2 {
        didSet {
            if !test.unit.contains(unit) {
                unit = test.unit.first ?? ""
            }
        }
    }
    var value = ""
    var unit: String = LabTest.e2.unit.first!
    var recordedAt = Date()
    private(set) var results: [LabResult] = []
    private(set) var visibleCount = 3
    private(set) var isBusy = false
    private(set) var message: String?
    private(set) var didSave = false

    @ObservationIgnored private let repository: any TrackingRepository
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let settings: UserDefaults

    init(repository: any TrackingRepository, locale: Locale = .current, settings: UserDefaults = .standard) {
        self.repository = repository
        self.locale = locale
        self.settings = settings
        useLatestE2ResultForCalibration = settings.bool(forKey: "useLatestE2ResultForLevelsCalibration")
    }

    var latestE2Result: LabResult? { results.first { $0.test == .e2 } }

    var visibleResults: [LabResult] { Array(results.prefix(visibleCount)) }
    var hasMoreResults: Bool { visibleCount < results.count }

    func showMore() { visibleCount = min(visibleCount + 3, results.count) }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await refreshResults()
            message = nil
        } catch {
            message = "Could not load lab results: \(error.localizedDescription)"
        }
    }

    func save() async {
        guard !isBusy else { return }
        isBusy = true
        didSave = false
        message = nil
        defer { isBusy = false }
        do {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = try? Double(text, format: .number.locale(locale), lenient: false) else {
                throw LabResultValidationError.invalidValue
            }
            let result = LabResult(id: UUID(), test: test, value: number, unit: unit, recordedAt: recordedAt)
            try result.validate()
            try await repository.save(result)
            didSave = true
            value = ""
        } catch {
            message = "Could not save lab result: \(error.localizedDescription)"
            return
        }
        do {
            try await refreshResults()
        } catch {
            message = "Lab result saved, but the list could not be refreshed: \(error.localizedDescription)"
        }
    }

    func delete(_ result: LabResult) async {
        guard !isBusy else { return }
        isBusy = true
        didSave = false
        message = nil
        defer { isBusy = false }
        do {
            try await repository.deleteLabResult(id: result.id)
            results.removeAll { $0.id == result.id }
        } catch {
            message = "Could not delete lab result: \(error.localizedDescription)"
        }
    }

    private func refreshResults() async throws {
        results = try await repository.labResults().sorted {
            if $0.recordedAt == $1.recordedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.recordedAt > $1.recordedAt
        }
    }
}
