import Foundation
import Testing
@testable import FemmeTrack

struct FemmeTrackTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen(dose: Double = 2, hours: Double = 24, until: Date? = nil) throws -> Regimen {
        try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)", doseMilligramsOfEster: dose,
                    intervalHours: hours, effectiveFrom: start, effectiveUntil: until,
                    timeZoneIdentifier: "Europe/Istanbul")
    }

    @Test func rejectsInvalidNumbers() {
        for value in [0, -1, Double.nan, .infinity, -.infinity] {
            #expect(throws: (any Error).self) { try regimen(dose: value) }
            #expect(throws: (any Error).self) { try regimen(hours: value) }
        }
    }

    @Test func initializationDoesNotGenerateEvents() throws {
        #expect(try regimen().injectionEvents.isEmpty)
    }

    @Test func extendingPreservesIDsAndCorrections() throws {
        let schedule = InjectionSchedule()
        var first = try schedule.extending(regimen(), through: start.addingTimeInterval(2 * 86400))
        first.injectionEvents[1].adjustment = .skipped
        let oldIDs = first.injectionEvents.map(\.id)
        let extended = try schedule.extending(first, through: start.addingTimeInterval(4 * 86400))
        #expect(extended.injectionEvents.count == 5)
        #expect(Array(extended.injectionEvents.prefix(3)).map(\.id) == oldIDs)
        #expect(extended.injectionEvents[1].adjustment == .skipped)
        let repeated = try schedule.extending(extended, through: start.addingTimeInterval(86400))
        #expect(repeated.injectionEvents.map(\.id) == extended.injectionEvents.map(\.id))
    }

    @Test func scheduleUsesElapsedTimeAndExclusiveEnd() throws {
        let end = start.addingTimeInterval(3 * 86400)
        let result = try InjectionSchedule().extending(regimen(until: end), through: end)
        #expect(result.injectionEvents.count == 3)
        #expect(result.injectionEvents.map(\.scheduledAt) == [start, start.addingTimeInterval(86400), start.addingTimeInterval(2 * 86400)])
    }

    @Test func scheduleBoundsWorkBeforeAllocation() throws {
        let tiny = try regimen(hours: 0.000000000001)
        #expect(throws: (any Error).self) {
            try InjectionSchedule().extending(tiny, through: start.addingTimeInterval(86400))
        }
        let excessive = try regimen(hours: 0.01)
        #expect(throws: (any Error).self) {
            try InjectionSchedule().extending(excessive, through: start.addingTimeInterval(366 * 86400))
        }
        let futureEnd = start.addingTimeInterval(-86400)
        #expect(try InjectionSchedule().extending(regimen(), through: futureEnd).injectionEvents.isEmpty)
    }

    @Test func legacyConfirmationsDecodeAndRoundTrip() throws {
        let id = UUID()
        let regimenID = UUID()
        let data = Data("""
        {"id":"\(id)","regimenID":"\(regimenID)","scheduledAt":"2023-11-14T22:13:20Z",
        "doseMilligramsOfEster":2,"adjustment":{"none":{}},"statusChangedManually":true}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(InjectionEvent.self, from: data)
        #expect(event.id == id)
        #expect(event.adjustment == .confirmed)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let roundTrip = try decoder.decode(InjectionEvent.self, from: encoder.encode(event))
        #expect(roundTrip.adjustment == .confirmed)
    }

    @Test func legacySubsecondSchedulesRetainCorrections() throws {
        var saved = try InjectionSchedule().extending(regimen(hours: 25.123456), through: start.addingTimeInterval(3 * 86400))
        saved.injectionEvents[1].adjustment = .skipped
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let reloaded = try decoder.decode(Regimen.self, from: encoder.encode(saved))
        let extended = try InjectionSchedule().extending(reloaded, through: start.addingTimeInterval(5 * 86400))
        #expect(extended.injectionEvents[1].id == saved.injectionEvents[1].id)
        #expect(extended.injectionEvents[1].adjustment == .skipped)
    }

    @Test func fractionalScheduleIncludesExactHorizonAndRespectsLimit() throws {
        let schedule = InjectionSchedule()
        let value = try regimen(hours: 25.123456)
        let end = start.addingTimeInterval(7 * value.intervalHours * 3600)
        #expect(try schedule.extending(value, through: end).injectionEvents.count == 8)
        let bounded = try regimen(until: start.addingTimeInterval(Double(InjectionSchedule.maximumEventCount) * 86400))
        #expect(try schedule.eventCount(for: bounded, through: bounded.effectiveUntil ?? start) == InjectionSchedule.maximumEventCount)
        #expect(throws: (any Error).self) {
            try schedule.eventCount(for: regimen(), through: start.addingTimeInterval(Double(InjectionSchedule.maximumEventCount) * 86400))
        }
    }

    @Test func statusesDistinguishProjectionFromAssumption() {
        let event = InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: start, doseMilligramsOfEster: 2)
        #expect(InjectionStatus(event: event, now: start.addingTimeInterval(-1)).title == "Upcoming")
        #expect(InjectionStatus(event: event, now: start).title == "Assumed taken")
    }
}
