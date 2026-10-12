import Foundation
import Testing
import EstradiolPK
@testable import fembie

struct SchedulingAndPredictionBoundaryTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen(start: Date? = nil) throws -> Regimen {
        try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
                    doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 24,
                    effectiveFrom: start ?? self.start, effectiveUntil: nil,
                    timeZoneIdentifier: "UTC")
    }

    @Test func scheduleRejectsNonFiniteHorizonAndMalformedExistingEvents() throws {
        let schedule = InjectionSchedule()
        #expect(throws: RegimenValidationError.self) {
            try schedule.eventCount(for: regimen(), through: Date(timeIntervalSinceReferenceDate: .nan))
        }

        var before = try regimen()
        before.injectionEvents = [
            InjectionEvent(id: UUID(), regimenID: before.id,
                           scheduledAt: start.addingTimeInterval(-1), doseMilligramsOfEster: 4)
        ]
        #expect(throws: RegimenValidationError.self) {
            try schedule.extending(before, through: start.addingTimeInterval(86_400))
        }

        var offGrid = try regimen()
        offGrid.injectionEvents = [
            InjectionEvent(id: UUID(), regimenID: offGrid.id,
                           scheduledAt: start.addingTimeInterval(1), doseMilligramsOfEster: 4)
        ]
        #expect(throws: RegimenValidationError.self) {
            try schedule.extending(offGrid, through: start.addingTimeInterval(86_400))
        }

        var duplicateSlot = try regimen()
        duplicateSlot.injectionEvents = [
            InjectionEvent(id: UUID(), regimenID: duplicateSlot.id,
                           scheduledAt: start, doseMilligramsOfEster: 4),
            InjectionEvent(id: UUID(), regimenID: duplicateSlot.id,
                           scheduledAt: start, doseMilligramsOfEster: 4)
        ]
        #expect(throws: RegimenValidationError.self) {
            try schedule.extending(duplicateSlot, through: start.addingTimeInterval(86_400))
        }
    }

    @Test func scheduleRejectsDuplicateIDsForeignEventsAndTooManyExistingEvents() throws {
        let schedule = InjectionSchedule()
        var duplicate = try regimen()
        let id = UUID()
        duplicate.injectionEvents = [
            InjectionEvent(id: id, regimenID: duplicate.id, scheduledAt: start, doseMilligramsOfEster: 4),
            InjectionEvent(id: id, regimenID: duplicate.id,
                           scheduledAt: start.addingTimeInterval(86_400), doseMilligramsOfEster: 4)
        ]
        #expect(throws: RegimenValidationError.self) {
            try schedule.extending(duplicate, through: start.addingTimeInterval(86_400))
        }

        var foreign = try regimen()
        foreign.injectionEvents = [
            InjectionEvent(id: UUID(), regimenID: UUID(), scheduledAt: start, doseMilligramsOfEster: 4)
        ]
        #expect(throws: RegimenValidationError.self) {
            try schedule.extending(foreign, through: start.addingTimeInterval(86_400))
        }

        var excessive = try regimen()
        excessive.intervalHours = 1
        excessive.injectionEvents = (0...InjectionSchedule.maximumEventCount).map { index in
            InjectionEvent(id: UUID(), regimenID: excessive.id,
                           scheduledAt: start.addingTimeInterval(Double(index) * 3_600),
                           doseMilligramsOfEster: 4)
        }
        #expect(throws: RegimenValidationError.self) {
            try schedule.extending(excessive, through: start)
        }
    }

    @Test func scheduleExcludesEventExactlyAtEffectiveUntilAndHandlesAdjacentBoundaries() throws {
        let interval = 25.123456 * 3_600
        var value = try regimen()
        value.intervalHours = 25.123456
        let exact = start.addingTimeInterval(7 * interval)
        value.effectiveUntil = exact
        let result = try InjectionSchedule().extending(value, through: exact)
        #expect(result.injectionEvents.count == 7)
        #expect(result.injectionEvents.last.map { $0.scheduledAt < exact } == true)

        var unbounded = try regimen()
        unbounded.intervalHours = 25.123456
        #expect(try InjectionSchedule().eventCount(for: unbounded,
            through: exact.addingTimeInterval(-0.001)) == 7)
        #expect(try InjectionSchedule().eventCount(for: unbounded, through: exact) == 8)
        #expect(try InjectionSchedule().eventCount(for: unbounded,
            through: exact.addingTimeInterval(0.001)) == 8)
    }

    @Test func calibrationValidationCoversTestUnitDatesAndNonFiniteValues() async throws {
        let calculator = LevelsPredictionCalculator()
        let value = try regimen()
        let now = start.addingTimeInterval(10 * 86_400)
        let valid = LabResult(id: UUID(), test: .e2, value: 100, recordedAt: start)
        _ = try await calculator.predict(regimen: value, now: now, calibrationResult: valid)
        _ = try await calculator.predict(regimen: value, now: now,
            calibrationResult: LabResult(id: UUID(), test: .e2, value: 100, recordedAt: now))

        let wrongTest = LabResult(id: UUID(), test: .lh, value: 10, recordedAt: start)
        await #expect(throws: LevelsPredictionError.self) {
            try await calculator.predict(regimen: value, now: now, calibrationResult: wrongTest)
        }

        let historicalData = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","test":"E2","value":100,"unit":"pmol/L","recordedAt":\(start.timeIntervalSinceReferenceDate)}
        """.utf8)
        let wrongUnit = try JSONDecoder().decode(LabResult.self, from: historicalData)
        await #expect(throws: LevelsPredictionError.self) {
            try await calculator.predict(regimen: value, now: now, calibrationResult: wrongUnit)
        }

        for date in [start.addingTimeInterval(-0.001), now.addingTimeInterval(0.001),
                     Date(timeIntervalSinceReferenceDate: .nan)] {
            let lab = LabResult(id: UUID(), test: .e2, value: 100, recordedAt: date)
            await #expect(throws: (any Error).self) {
                try await calculator.predict(regimen: value, now: now, calibrationResult: lab)
            }
        }
        for number in [Double.nan, .infinity, -.infinity] {
            let lab = LabResult(id: UUID(), test: .e2, value: number, recordedAt: start)
            await #expect(throws: (any Error).self) {
                try await calculator.predict(regimen: value, now: now, calibrationResult: lab)
            }
        }
    }

    @Test func calibrationOutsideDisplayedWindowAppliesWithoutAddingOutOfRangeTimestamp() async throws {
        let oldStart = start.addingTimeInterval(-100 * 86_400)
        let value = try regimen(start: oldStart)
        let labDate = start.addingTimeInterval(-15 * 86_400)
        let now = start
        let points = try await LevelsPredictionCalculator().predict(
            regimen: value,
            now: now,
            calibrationResult: LabResult(id: UUID(), test: .e2, value: 100, recordedAt: labDate)
        )
        #expect(!points.contains { $0.timestamp == labDate })
        #expect(points.first?.timestamp == now.addingTimeInterval(-14 * 86_400))
    }

    @Test func clampSetsRateToZeroAtAndBelowZero() async throws {
        let value = try regimen()
        let labDate = start.addingTimeInterval(86_400)
        let points = try await LevelsPredictionCalculator().predict(
            regimen: value,
            now: start.addingTimeInterval(2 * 86_400),
            calibrationResult: LabResult(id: UUID(), test: .e2, value: 0, recordedAt: labDate)
        )
        let measurement = try #require(points.first { $0.timestamp == labDate })
        #expect(measurement.estradiolPicogramsPerMilliliter == 0)
        #expect(measurement.rateOfChangePicogramsPerMilliliterPerHour == 0)
        #expect(points.filter { $0.estradiolPicogramsPerMilliliter == 0 }
            .allSatisfy { $0.rateOfChangePicogramsPerMilliliterPerHour == 0 })
    }

    @Test func detectorRejectsSmallAndNonFiniteInputs() {
        let detector = LevelEventDetector()
        let point = PredictionPoint(timestamp: start, estradiolPicogramsPerMilliliter: 1,
                                    rateOfChangePicogramsPerMilliliterPerHour: 1)
        #expect(detector.events(in: [], kinds: [.e2Peak], after: .distantPast).isEmpty)
        #expect(detector.events(in: [point, point], kinds: [.e2Peak], after: .distantPast).isEmpty)
        let invalidLevel = PredictionPoint(timestamp: start.addingTimeInterval(1),
                                           estradiolPicogramsPerMilliliter: .nan,
                                           rateOfChangePicogramsPerMilliliterPerHour: 0)
        let invalidRate = PredictionPoint(timestamp: start.addingTimeInterval(2),
                                          estradiolPicogramsPerMilliliter: 1,
                                          rateOfChangePicogramsPerMilliliterPerHour: .infinity)
        #expect(detector.events(in: [point, invalidLevel, point], kinds: [.e2Peak], after: .distantPast).isEmpty)
        #expect(detector.events(in: [point, invalidRate, point], kinds: [.rateHighest], after: .distantPast).isEmpty)
    }

    @Test func detectorHandlesUnsortedDuplicateAndUnevenTimestampsDeterministically() throws {
        let detector = LevelEventDetector()
        let points = [
            PredictionPoint(timestamp: start.addingTimeInterval(30), estradiolPicogramsPerMilliliter: 1,
                            rateOfChangePicogramsPerMilliliterPerHour: 0),
            PredictionPoint(timestamp: start.addingTimeInterval(10), estradiolPicogramsPerMilliliter: 1,
                            rateOfChangePicogramsPerMilliliterPerHour: 0),
            PredictionPoint(timestamp: start.addingTimeInterval(20), estradiolPicogramsPerMilliliter: 3,
                            rateOfChangePicogramsPerMilliliterPerHour: 2),
            PredictionPoint(timestamp: start.addingTimeInterval(20), estradiolPicogramsPerMilliliter: 3,
                            rateOfChangePicogramsPerMilliliterPerHour: 2)
        ]
        let events = detector.events(in: points, kinds: [.e2Peak, .rateHighest], after: start)
        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.timestamp == start.addingTimeInterval(20) })
        #expect(events.map(\.kind.rawValue) == events.map(\.kind.rawValue).sorted())

        let uneven = [
            PredictionPoint(timestamp: start, estradiolPicogramsPerMilliliter: 1,
                            rateOfChangePicogramsPerMilliliterPerHour: 0),
            PredictionPoint(timestamp: start.addingTimeInterval(10), estradiolPicogramsPerMilliliter: 3,
                            rateOfChangePicogramsPerMilliliterPerHour: 0),
            PredictionPoint(timestamp: start.addingTimeInterval(40), estradiolPicogramsPerMilliliter: 2,
                            rateOfChangePicogramsPerMilliliterPerHour: 0)
        ]
        #expect(detector.events(in: uneven, kinds: [.e2Peak], after: start).first?.timestamp
                == start.addingTimeInterval(10))
    }

    @Test func detectorToleranceDistinguishesNearlyEqualValues() {
        let detector = LevelEventDetector()
        func events(delta: Double) -> [LevelNotificationEvent] {
            detector.events(in: [
                PredictionPoint(timestamp: start, estradiolPicogramsPerMilliliter: 1,
                                rateOfChangePicogramsPerMilliliterPerHour: 0),
                PredictionPoint(timestamp: start.addingTimeInterval(10),
                                estradiolPicogramsPerMilliliter: 1 + delta,
                                rateOfChangePicogramsPerMilliliterPerHour: 0),
                PredictionPoint(timestamp: start.addingTimeInterval(20), estradiolPicogramsPerMilliliter: 1,
                                rateOfChangePicogramsPerMilliliterPerHour: 0)
            ], kinds: [.e2Peak], after: start)
        }
        #expect(events(delta: 0.5e-9).isEmpty)
        #expect(events(delta: 2e-9).count == 1)
    }
}
