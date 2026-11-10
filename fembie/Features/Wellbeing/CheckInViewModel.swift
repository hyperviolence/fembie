import Foundation
import SwiftUI

@MainActor
@Observable
final class CheckInViewModel {
    private(set) var isBusy = false
    private(set) var isSaving = false
    private(set) var lastSavedCheckInDate: Date?
    private(set) var saveError: String?
    private(set) var checkIns: [CheckIn] = []
    private(set) var historyError: String?
    var customRatings: [CustomWellbeingRating] = []
    private(set) var metricError: String?
    private(set) var metricDeletionError: String?

    func deleteCustomMetric(id: UUID) async {
        guard !isBusy else { return }
        isBusy = true
        metricDeletionError = nil
        defer { isBusy = false }
        do {
            try await repository.deleteCustomMetric(id: id)
            customRatings.removeAll { $0.id == id }
            for index in checkIns.indices {
                checkIns[index].customRatings.removeAll { $0.id == id }
            }
        } catch {
            metricDeletionError = String(localized: "Could not delete the custom metric. Please try again.")
        }
    }

    @discardableResult
    func addCustomMetric(label: String, lowLabel: String, highLabel: String) -> Bool {
        let rating = CustomWellbeingRating(
            id: UUID(),
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            lowLabel: lowLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            highLabel: highLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            value: 5
        )
        do {
            try rating.validate()
            let existingLabels = ["Mood", "Libido", "Energy"] + customRatings.map(\.label)
            guard !existingLabels.contains(where: {
                $0.compare(rating.label, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) else {
                metricError = String(localized: "A metric with this name already exists.")
                return false
            }
            customRatings.append(rating)
            metricError = nil
            return true
        } catch {
            metricError = String(localized: "Enter a name and both scale labels, each up to 100 characters.")
            return false
        }
    }
    @ObservationIgnored private let repository: any TrackingRepository
    @ObservationIgnored private var hasLoadedCheckIns = false
    
    init(repository: any TrackingRepository) {
        self.repository = repository
    }
    
    func loadCheckIns() async {
        guard !isBusy, !hasLoadedCheckIns else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await refreshHistory()
        } catch {
            historyError = "Could not load check-ins: \(error.localizedDescription)"
        }
    }

    func reloadCheckIns() async {
        guard !isBusy else { return }
        hasLoadedCheckIns = false
        customRatings = []
        await loadCheckIns()
    }

    func saveCheckIn(date: Date, mood: Double, libido: Double, energy: Double) async {
        guard !isBusy else {
            saveError = isSaving ? "A check-in is already being saved." : "Check-ins are still loading. Please try again."
            return
        }
        isBusy = true
        isSaving = true
        lastSavedCheckInDate = nil
        saveError = nil
        defer {
            isBusy = false
            isSaving = false
        }
        do {
            let checkIn = CheckIn(id: UUID(), recordedAt: date, mood: mood, libido: libido, energy: energy,
                                  customRatings: customRatings)
            try checkIn.validate()
            try await repository.save(checkIn)
            lastSavedCheckInDate = date
        } catch {
            saveError = "Could not save check-in: \(error.localizedDescription)"
            return
        }
        do {
            try await refreshHistory()
        } catch {
            historyError = "Check-in saved, but history could not be refreshed: \(error.localizedDescription)"
        }
    }

    func resetData() async throws {
        guard !isBusy else {
            throw NSError(domain: "CheckInViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Your check-ins are still being updated. Please try again."])
        }
        isBusy = true
        defer { isBusy = false }
        try await repository.resetWellbeingData()
        checkIns = []
        customRatings = []
        metricError = nil
        hasLoadedCheckIns = true
        lastSavedCheckInDate = nil
        saveError = nil
        historyError = nil
    }

    func dailyAverages(calendar: Calendar = .current) -> [DailyCheckInAverage] {
        let days = Dictionary(grouping: checkIns) { calendar.startOfDay(for: $0.recordedAt) }
        return days.map { date, entries in
            let count = Double(entries.count)
            return DailyCheckInAverage(
                date: date,
                mood: entries.reduce(0) { $0 + $1.mood } / count,
                libido: entries.reduce(0) { $0 + $1.libido } / count,
                energy: entries.reduce(0) { $0 + $1.energy } / count,
                customRatings: Dictionary(grouping: entries.flatMap(\.customRatings), by: \.id)
                    .values.compactMap { ratings in
                        guard var average = ratings.last else { return nil }
                        average.value = ratings.reduce(0) { $0 + $1.value } / Double(ratings.count)
                        return average
                    }
                    .sorted { $0.id.uuidString < $1.id.uuidString }
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func refreshHistory() async throws {
        let loadedCheckIns = try await repository.checkIns()
        let sortedCheckIns = await Task.detached {
            loadedCheckIns.sorted { $0.recordedAt < $1.recordedAt }
        }.value
        // Reuse saved metric definitions, including metrics absent from the latest check-in.
        var ratingsByID: [UUID: CustomWellbeingRating] = [:]
        for checkIn in sortedCheckIns {
            for rating in checkIn.customRatings { ratingsByID[rating.id] = rating }
        }
        // Keep unsaved form edits when refreshing after a save.
        for rating in customRatings { ratingsByID[rating.id] = rating }
        customRatings = ratingsByID.values.sorted {
            $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
        checkIns = sortedCheckIns
        hasLoadedCheckIns = true
        historyError = nil
    }
}
