import Foundation
import Testing
@testable import fembie

@MainActor
struct CheckInViewModelTests {
    @Test func historyLoadsInChronologicalOrder() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CheckInHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let earlier = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 100),
                              mood: 2, libido: 3, energy: 4)
        let later = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 200),
                            mood: 8, libido: 7, energy: 6)
        try await repository.save(later)
        try await repository.save(earlier)
        let model = CheckInViewModel(repository: repository)

        await model.loadCheckIns()

        #expect(model.checkIns.map(\.id) == [earlier.id, later.id])
        #expect(model.historyError == nil)
        #expect(!model.isBusy)
    }

    @Test func savingRefreshesHistoryAndSurvivesReload() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CheckInHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let previous = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 100),
                               mood: 2, libido: 3, energy: 4)
        try await repository.save(previous)
        let model = CheckInViewModel(repository: repository)

        await model.saveCheckIn(date: .now, mood: 8, libido: 6, energy: 9)

        #expect(model.checkIns.count == 2)
        #expect(model.lastSavedCheckInDate == model.checkIns.last?.recordedAt)
        #expect(model.saveError == nil)
        #expect(!model.isSaving)
        #expect(model.checkIns.first?.id == previous.id)
        #expect(model.checkIns.last?.mood == 8)
        #expect(model.checkIns.last?.libido == 6)
        #expect(model.checkIns.last?.energy == 9)
        let reloaded = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        await reloaded.loadCheckIns()
        #expect(reloaded.checkIns.map(\.id) == model.checkIns.map(\.id))
        #expect(reloaded.historyError == nil)
    }

    @Test func failedSaveKeepsHistoryUnchanged() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CheckInHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let previous = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 100),
                               mood: 2, libido: 3, energy: 4)
        try await repository.save(previous)
        let model = CheckInViewModel(repository: repository)
        await model.loadCheckIns()
        let file = directory.appending(path: "checkIns.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)

        await model.saveCheckIn(date: .now, mood: 8, libido: 6, energy: 9)

        #expect(model.checkIns.map(\.id) == [previous.id])
        #expect(model.saveError != nil)
        #expect(model.lastSavedCheckInDate == nil)
        #expect(!model.isBusy)
        #expect(!model.isSaving)
    }

    @Test func dailyAveragesCombineRatingsWithoutChangingSavedCheckIns() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CheckInHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let earlier = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 100),
                              mood: 2, libido: 3, energy: 4)
        let sameDay = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 3600),
                              mood: 5, libido: 8, energy: 9)
        let nextDay = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 86400),
                              mood: 7, libido: 1, energy: 10)
        for checkIn in [nextDay, sameDay, earlier] {
            try await repository.save(checkIn)
        }
        let model = CheckInViewModel(repository: repository)
        #expect(model.dailyAverages(calendar: calendar).isEmpty)
        await model.loadCheckIns()

        let averages = model.dailyAverages(calendar: calendar)

        #expect(averages.map(\.date) == [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 86400)])
        #expect(averages.first?.mood == 3.5)
        #expect(averages.first?.libido == 5.5)
        #expect(averages.first?.energy == 6.5)
        #expect(averages.last?.mood == 7)
        #expect(averages.last?.libido == 1)
        #expect(averages.last?.energy == 10)
        #expect(model.checkIns.count == 3)
        #expect(try await repository.checkIns().count == 3)
    }

    @Test func dailyAveragesUseLocalMidnightBoundaries() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CheckInHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        for hour in [20.0, 22.0] {
            try await repository.save(CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: hour * 3600),
                                             mood: 4, libido: 5, energy: 6))
        }
        let model = CheckInViewModel(repository: repository)
        await model.loadCheckIns()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        #expect(model.dailyAverages(calendar: calendar).count == 1)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 3 * 3600))
        let averages = model.dailyAverages(calendar: calendar)
        #expect(averages.count == 2)
        #expect(averages.allSatisfy { calendar.component(.hour, from: $0.date) == 0 })
    }

    @Test func identicalCheckInsStillSaveIndividuallyAndConfirmSelectedDate() async throws {
        let directory = URL.temporaryDirectory.appending(path: "CheckInHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CheckInViewModel(repository: FileTrackingRepository(baseURL: directory))
        let selectedDate = Date(timeIntervalSince1970: 100)

        await model.saveCheckIn(date: selectedDate, mood: 5, libido: 5, energy: 5)
        await model.saveCheckIn(date: selectedDate, mood: 5, libido: 5, energy: 5)

        #expect(model.checkIns.count == 2)
        #expect(Set(model.checkIns.map(\.id)).count == 2)
        #expect(model.lastSavedCheckInDate == selectedDate)
        #expect(model.saveError == nil)
        #expect(model.dailyAverages().count == 1)
        #expect(model.dailyAverages().first?.mood == 5)
        let persisted = try await FileTrackingRepository(baseURL: directory).checkIns()
        #expect(persisted.count == 2)
        #expect(persisted.allSatisfy { $0.recordedAt == selectedDate })
    }
}
