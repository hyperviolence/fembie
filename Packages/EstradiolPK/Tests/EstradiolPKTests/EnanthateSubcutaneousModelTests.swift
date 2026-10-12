import Foundation
import Testing
@testable import EstradiolPK

struct EnanthateSubcutaneousModelTests {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private let model = EnanthateSubcutaneousModel()

    // Reference values from independent RK4 integration of the three-compartment ODEs,
    // with k1 = 0.1071, k2 = 0.601, k3 = 0.402 and scale = 191.4.
    @Test func matchesReducedDepotRateSingleDoseFixtures() throws {
        let days = [-1.0, 0, 1, 3, 7, 14]
        let expected = [0.0, 0.0, 4.276811901046778, 19.147017642337165, 29.24505222181612, 18.157667210420232]
        let result = try model.predict(doses: [DoseAdministration(timestamp: origin, milligramsOfEster: 1)],
            at: days.map { origin.addingTimeInterval($0 * 86_400) })
        for (point, value) in zip(result, expected) {
            #expect(abs(point.estradiolPicogramsPerMilliliter - value) < 1e-9)
        }
    }

    @Test func matchesReducedDepotRateRepeatedDoseFixture() throws {
        let doses = [DoseAdministration(timestamp: origin, milligramsOfEster: 4),
                     DoseAdministration(timestamp: origin.addingTimeInterval(7 * 86_400), milligramsOfEster: 4)]
        let result = try model.predict(doses: doses, at: [origin.addingTimeInterval(10 * 86_400)])
        let point = try #require(result.first)
        #expect(abs(point.estradiolPicogramsPerMilliliter - 178.68010012166602) < 1e-9)
    }

    @Test func derivativeMatchesIndependentFiniteDifference() throws {
        let doses = [DoseAdministration(timestamp: origin, milligramsOfEster: 4)]
        for day in [1.0, 3, 7, 14] {
            let date = origin.addingTimeInterval(day * 86_400)
            let result = try model.predict(doses: doses,
                at: [date.addingTimeInterval(-30), date, date.addingTimeInterval(30)])
            let perHour = (result[2].estradiolPicogramsPerMilliliter
                - result[0].estradiolPicogramsPerMilliliter) * 60
            #expect(abs(result[1].rateOfChangePicogramsPerMilliliterPerHour - perHour) < 1e-6)
        }
    }

    @Test func futureDosesAndEmptyHistoryDoNotContribute() throws {
        let doses = [DoseAdministration(timestamp: origin.addingTimeInterval(86_400), milligramsOfEster: 4)]
        for history in [doses, []] {
            let result = try model.predict(doses: history, at: [origin])
            let point = try #require(result.first)
            #expect(point.estradiolPicogramsPerMilliliter == 0)
            #expect(point.rateOfChangePicogramsPerMilliliterPerHour == 0)
        }
    }



    @Test func zeroDoseProducesZeroAndEmptyTimestampsProduceNoPoints() throws {
        let result = try model.predict(
            doses: [DoseAdministration(timestamp: origin, milligramsOfEster: 0)],
            at: [origin.addingTimeInterval(86_400)]
        )
        #expect(result.first?.estradiolPicogramsPerMilliliter == 0)
        #expect(result.first?.rateOfChangePicogramsPerMilliliterPerHour == 0)
        #expect(try model.predict(doses: [], at: []).isEmpty)
    }

    @Test func rejectsNonFiniteDoseDatesAndOverflowingFiniteDoses() {
        #expect(throws: EnanthatePredictionError.self) {
            try model.predict(
                doses: [DoseAdministration(
                    timestamp: Date(timeIntervalSinceReferenceDate: .nan),
                    milligramsOfEster: 1
                )],
                at: [origin]
            )
        }
        #expect(throws: EnanthatePredictionError.self) {
            try model.predict(
                doses: [DoseAdministration(timestamp: origin, milligramsOfEster: .greatestFiniteMagnitude)],
                at: [origin.addingTimeInterval(86_400)]
            )
        }
    }

    @Test func doseAndOutputOrderingAreExplicitAndDuplicateDatesAccumulate() throws {
        let earlier = DoseAdministration(timestamp: origin, milligramsOfEster: 1)
        let later = DoseAdministration(timestamp: origin.addingTimeInterval(86_400), milligramsOfEster: 2)
        let timestamps = [
            origin.addingTimeInterval(3 * 86_400),
            origin.addingTimeInterval(2 * 86_400)
        ]
        let ordered = try model.predict(doses: [earlier, later], at: timestamps)
        let reversed = try model.predict(doses: [later, earlier], at: timestamps)
        #expect(zip(ordered, reversed).allSatisfy {
            abs($0.estradiolPicogramsPerMilliliter - $1.estradiolPicogramsPerMilliliter) < 1e-12
        })
        #expect(ordered.map(\.timestamp) == timestamps)

        let single = try model.predict(doses: [earlier], at: [timestamps[0]])[0]
        let duplicate = try model.predict(doses: [earlier, earlier], at: [timestamps[0]])[0]
        #expect(abs(duplicate.estradiolPicogramsPerMilliliter
                    - 2 * single.estradiolPicogramsPerMilliliter) < 1e-9)
    }

    @Test func rejectsInvalidInputs() {
        for dose in [-1.0, .nan, .infinity] {
            #expect(throws: EnanthatePredictionError.self) {
                try model.predict(doses: [DoseAdministration(timestamp: origin, milligramsOfEster: dose)], at: [origin])
            }
        }
        #expect(throws: EnanthatePredictionError.self) {
            try model.predict(doses: [], at: [Date(timeIntervalSinceReferenceDate: .nan)])
        }
    }
}
