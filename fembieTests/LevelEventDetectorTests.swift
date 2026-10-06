import Foundation
import Testing
import EstradiolPK
@testable import fembie

struct LevelEventDetectorTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func points(_ levels: [Double], rates: [Double]? = nil) -> [PredictionPoint] {
        levels.enumerated().map { index, level in
            PredictionPoint(timestamp: start.addingTimeInterval(Double(index) * 3_600),
                estradiolPicogramsPerMilliliter: level,
                rateOfChangePicogramsPerMilliliterPerHour: rates?[index] ?? 0)
        }
    }

    @Test func findsEveryPeakAndLowAcrossMultipleCycles() {
        let events = LevelEventDetector().events(in: points([0, 3, 1, 0, 1, 3, 0]),
            kinds: [.e2Peak, .e2Low], after: start)
        #expect(events.map(\.kind) == [.e2Peak, .e2Low, .e2Peak])
        #expect(events[1].timestamp == start.addingTimeInterval(3 * 3_600))
        #expect(events.map(\.id).count == Set(events.map(\.id)).count)
    }

    @Test func rateExtremaUseSignedValuesRatherThanMagnitude() {
        let events = LevelEventDetector().events(in: points([1, 1, 1, 1, 1, 1, 1],
            rates: [-2, 1, 3, 1, -3, -1, 2]), kinds: [.rateHighest, .rateLowest], after: start)
        #expect(events.map(\.kind) == [.rateHighest, .rateLowest])
        #expect(events[0].timestamp == start.addingTimeInterval(2 * 3_600))
        #expect(events[1].timestamp > start.addingTimeInterval(3 * 3_600))
    }

    @Test func plateauProducesOneEventAtItsBeginningAndFlatCurvesProduceNone() {
        let detector = LevelEventDetector()
        let events = detector.events(in: points([1, 3, 3, 3, 1, 0, 0, 1]),
            kinds: [.e2Peak, .e2Low], after: start)
        #expect(events.map(\.timestamp) == [start.addingTimeInterval(3_600), start.addingTimeInterval(5 * 3_600)])
        #expect(detector.events(in: points([0, 0, 0, 0]), kinds: Set(LevelNotificationKind.allCases), after: start).isEmpty)
        #expect(detector.events(in: points([0, 0, 0, 1, 2]), kinds: [.e2Low], after: start).isEmpty)
        #expect(detector.events(in: points([1, 2, 3, 4]), kinds: [.e2Peak, .e2Low], after: start).isEmpty)
    }

    @Test func refinesTimingAndExcludesPastEventsUnselectedKindsAndEndpoints() {
        let detector = LevelEventDetector()
        let curve = points([0, 10, 8])
        let event = detector.events(in: curve, kinds: [.e2Peak], after: start).first
        #expect(event?.timestamp == start.addingTimeInterval(4_800))
        #expect(detector.events(in: curve, kinds: [.e2Peak], after: start.addingTimeInterval(4_800)).isEmpty)
        #expect(detector.events(in: curve, kinds: [.e2Low], after: start).isEmpty)
        #expect(detector.events(in: Array(curve.prefix(2)), kinds: [.e2Peak], after: start).isEmpty)
    }

    @Test func notificationForecastExtendsNinetyDaysWhileChartStaysAtFourteen() async throws {
        let regimen = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 7 * 24,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
        let now = start.addingTimeInterval(84 * 86_400)
        let calculator = LevelsPredictionCalculator()
        let chart = try await calculator.predict(regimen: regimen, now: now)
        let forecast = try await calculator.predict(regimen: regimen, now: now, horizon: .notifications)
        #expect(chart.count == 673)
        #expect(chart.last?.timestamp == now.addingTimeInterval(14 * 86_400))
        #expect(forecast.count == 2_497)
        #expect(forecast.last?.timestamp == now.addingTimeInterval(90 * 86_400))
        // Extending the schedule must not alter predictions within the chart window.
        #expect(Array(forecast.prefix(chart.count)).map(\.estradiolPicogramsPerMilliliter)
                == chart.map(\.estradiolPicogramsPerMilliliter))
        let events = LevelEventDetector().events(in: forecast, kinds: Set(LevelNotificationKind.allCases), after: now)
        #expect(events.contains { $0.timestamp > now.addingTimeInterval(80 * 86_400) })
        #expect(events.allSatisfy { $0.timestamp <= now.addingTimeInterval(90 * 86_400) })
    }

    @Test func clockHourGridKeepsEventTimesStableAcrossRefreshes() async throws {
        let regimen = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 7 * 24,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
        let now = start.addingTimeInterval(84 * 86_400)
        let calculator = LevelsPredictionCalculator()
        let first = try await calculator.predict(regimen: regimen, now: now, alignSamplesToHour: true, horizon: .notifications)
        let second = try await calculator.predict(regimen: regimen, now: now.addingTimeInterval(60), alignSamplesToHour: true, horizon: .notifications)
        let detector = LevelEventDetector()
        let events = detector.events(in: first, kinds: Set(LevelNotificationKind.allCases), after: now)
        #expect(!events.isEmpty)
        #expect(events == detector.events(in: second, kinds: Set(LevelNotificationKind.allCases), after: now))
        #expect(Set(events.map(\.kind)) == Set(LevelNotificationKind.allCases))
    }
}
