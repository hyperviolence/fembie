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
    @ObservationIgnored private let repository: any TrackingRepository
    
    init(repository: any TrackingRepository) {
        self.repository = repository
    }
    
    func loadCheckIns() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await refreshHistory()
        } catch {
            historyError = "Could not load check-ins: \(error.localizedDescription)"
        }
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
            let checkIn = CheckIn(id: UUID(), recordedAt: date, mood: mood, libido: libido, energy: energy)
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
                energy: entries.reduce(0) { $0 + $1.energy } / count
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func refreshHistory() async throws {
        checkIns = try await repository.checkIns().sorted { $0.recordedAt < $1.recordedAt }
        historyError = nil
    }
}
