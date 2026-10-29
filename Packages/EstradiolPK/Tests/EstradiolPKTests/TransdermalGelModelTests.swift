import Foundation
import Testing
@testable import EstradiolPK

struct TransdermalGelModelTests {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private let model = TransdermalGelModel()

    @Test func matchesIndependentSingleDoseFixtures() throws {
        let hours = [1.0, 4, 8, 24, 72, 168]
        let expected = [3.681778127301223, 11.486342078301202, 16.59228725834284,
                        14.694987086373377, 3.1131983392834828, 0.41640654932493]
        let points = try model.predict(doses: [.init(timestamp: origin, milligramsOfEster: 1)],
            at: hours.map { origin.addingTimeInterval($0 * 3_600) })
        for (point, fixture) in zip(points, expected) {
            #expect(abs(point.estradiolPicogramsPerMilliliter - fixture) < 1e-10)
        }
    }

    @Test func derivativeMatchesFiniteDifferencesDuringRiseAndWashout() throws {
        let doses = [DoseAdministration(timestamp: origin, milligramsOfEster: 2)]
        for hour in [0.01, 1, 8, 16, 24, 72, 168] {
            let date = origin.addingTimeInterval(hour * 3_600)
            let points = try model.predict(doses: doses,
                at: [date.addingTimeInterval(-1), date, date.addingTimeInterval(1)])
            let numerical = (points[2].estradiolPicogramsPerMilliliter
                - points[0].estradiolPicogramsPerMilliliter) * 1_800
            #expect(abs(points[1].rateOfChangePicogramsPerMilliliterPerHour - numerical) < 1e-6)
        }
    }

    @Test func dailyAverageMatchesLabelBasedExposureConstruction() throws {
        let doses = (0..<90).map {
            DoseAdministration(timestamp: origin.addingTimeInterval(Double($0) * 86_400), milligramsOfEster: 1)
        }
        let start = origin.addingTimeInterval(89 * 86_400)
        let points = try model.predict(doses: doses,
            at: (0...1_440).map { start.addingTimeInterval(Double($0) * 60) })
        // Independent trapezoidal integration over a settled daily interval.
        let area = zip(points, points.dropFirst()).reduce(0.0) {
            $0 + ($1.0.estradiolPicogramsPerMilliliter + $1.1.estradiolPicogramsPerMilliliter) / 120
        }
        #expect(abs(area / 24 - 35.41904761904762) < 0.0001)
        // Agreement with Cavg is not validation of individual peaks.
        for (dose, observed) in [(0.25, 9.8), (0.5, 21.0), (0.75, 28.3), (1.0, 30.5)] {
            #expect(abs(area / 24 * dose - observed) / observed < 0.17)
        }
    }

    @Test func integratedSingleDoseExposureMatchesDailyAverage() throws {
        let points = try model.predict(doses: [.init(timestamp: origin, milligramsOfEster: 1)],
            at: (0...60_000).map { origin.addingTimeInterval(Double($0) * 60) })
        let area = zip(points, points.dropFirst()).reduce(0.0) {
            $0 + ($1.0.estradiolPicogramsPerMilliliter + $1.1.estradiolPicogramsPerMilliliter) / 120
        }
        #expect(abs(area - 850.0571428571429) < 0.001)
    }

    @Test func causalAtApplicationAndStableImmediatelyAfterward() throws {
        let points = try model.predict(doses: [.init(timestamp: origin, milligramsOfEster: 1)],
            at: [-1.0, 0, 0.001].map { origin.addingTimeInterval($0) })
        #expect(points[0].estradiolPicogramsPerMilliliter == 0)
        #expect(points[1].estradiolPicogramsPerMilliliter == 0)
        #expect(points[1].rateOfChangePicogramsPerMilliliterPerHour == 0)
        #expect(points[2].estradiolPicogramsPerMilliliter > 0)
        #expect(points[2].rateOfChangePicogramsPerMilliliterPerHour > 0)
    }

    @Test func repeatedAndSplitDosesSuperposeAndPreserveSampleOrder() throws {
        let first = DoseAdministration(timestamp: origin, milligramsOfEster: 1)
        let second = DoseAdministration(timestamp: origin.addingTimeInterval(12 * 3_600), milligramsOfEster: 0.5)
        let dates = [48.0, 8, 24, 24].map { origin.addingTimeInterval($0 * 3_600) }
        let combined = try model.predict(doses: [second, first], at: dates)
        let a = try model.predict(doses: [first], at: dates)
        let b = try model.predict(doses: [second], at: dates)
        #expect(combined.map(\.timestamp) == dates)
        for index in dates.indices {
            #expect(abs(combined[index].estradiolPicogramsPerMilliliter
                - a[index].estradiolPicogramsPerMilliliter - b[index].estradiolPicogramsPerMilliliter) < 1e-10)
            #expect(abs(combined[index].rateOfChangePicogramsPerMilliliterPerHour
                - a[index].rateOfChangePicogramsPerMilliliterPerHour
                - b[index].rateOfChangePicogramsPerMilliliterPerHour) < 1e-10)
        }
        let double = try model.predict(doses: [first, first], at: dates)
        #expect(abs(double[0].estradiolPicogramsPerMilliliter - 2 * a[0].estradiolPicogramsPerMilliliter) < 1e-10)
    }

    @Test func accumulatesThenWashesOutWithoutNegativeLevels() throws {
        let doses = (0..<14).map {
            DoseAdministration(timestamp: origin.addingTimeInterval(Double($0) * 86_400), milligramsOfEster: 1)
        }
        let dates = [8.0, 13 * 24 + 8, 30 * 24, 90 * 24].map { origin.addingTimeInterval($0 * 3_600) }
        let points = try model.predict(doses: doses, at: dates)
        #expect(points[1].estradiolPicogramsPerMilliliter > points[0].estradiolPicogramsPerMilliliter)
        #expect(points[2].rateOfChangePicogramsPerMilliliterPerHour < 0)
        #expect(points[3].estradiolPicogramsPerMilliliter < 1e-10)
        #expect(points.allSatisfy { $0.estradiolPicogramsPerMilliliter >= 0 })
    }

    @Test func emptyHistoryZeroDoseAndEmptySamples() throws {
        for doses: [DoseAdministration] in [[], [.init(timestamp: origin, milligramsOfEster: 0)]] {
            let points = try model.predict(doses: doses, at: [origin.addingTimeInterval(3_600)])
            #expect(points[0].estradiolPicogramsPerMilliliter == 0)
            #expect(points[0].rateOfChangePicogramsPerMilliliterPerHour == 0)
        }
        #expect(try model.predict(doses: [], at: []).isEmpty)
    }

    @Test func rejectsInvalidInputsAndOverflow() {
        for dose in [-1.0, .nan, .infinity, -.infinity] {
            #expect(throws: GelPredictionError.invalidInput) {
                try model.predict(doses: [.init(timestamp: origin, milligramsOfEster: dose)], at: [origin])
            }
        }
        for seconds in [Double.nan, .infinity, -.infinity] {
            let invalid = Date(timeIntervalSinceReferenceDate: seconds)
            #expect(throws: GelPredictionError.invalidInput) {
                try model.predict(doses: [.init(timestamp: invalid, milligramsOfEster: 1)], at: [origin])
            }
            #expect(throws: GelPredictionError.invalidInput) {
                try model.predict(doses: [], at: [invalid])
            }
        }
        #expect(throws: GelPredictionError.nonFiniteResult) {
            try model.predict(doses: [.init(timestamp: origin, milligramsOfEster: .greatestFiniteMagnitude)],
                              at: [origin.addingTimeInterval(8 * 3_600)])
        }
    }
}
