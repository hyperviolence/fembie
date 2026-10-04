import Foundation
import SwiftUI

@MainActor
@Observable
final class CheckInViewModel {
    private(set) var isBusy = false
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
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let checkIn = CheckIn(id: UUID(), recordedAt: date, mood: mood, libido: libido, energy: energy)
            try await repository.save(checkIn)
        } catch {
            historyError = "Could not save check-in: \(error.localizedDescription)"
            return
        }
        do {
            try await refreshHistory()
        } catch {
            historyError = "Check-in saved, but history could not be refreshed: \(error.localizedDescription)"
        }
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
