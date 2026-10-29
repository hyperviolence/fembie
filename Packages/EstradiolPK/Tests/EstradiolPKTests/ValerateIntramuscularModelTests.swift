import Foundation
import Testing
@testable import EstradiolPK

struct ValerateIntramuscularModelTests {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private let model = ValerateIntramuscularModel()

    // Generated from the supplied Estrannaise models.js + modeldata.js, EV im.
    @Test func matchesJavaScriptSingleDoseFixtures() throws {
        let days = [-1.0, 0, 1, 3, 7, 14]
        let expected = [0.0, 0, 49.85131369903763, 54.52399447267084,
                        22.61118803669431, 4.338713074613048]
        let result = try model.predict(doses: [DoseAdministration(timestamp: origin, milligramsOfEster: 1)],
            at: days.map { origin.addingTimeInterval($0 * 86_400) })
        for (point, value) in zip(result, expected) {
            #expect(abs(point.estradiolPicogramsPerMilliliter - value) < 1e-9)
        }
    }

    @Test func matchesJavaScriptRepeatedDoseFixture() throws {
        let doses = [DoseAdministration(timestamp: origin, milligramsOfEster: 4),
                     DoseAdministration(timestamp: origin.addingTimeInterval(7 * 86_400), milligramsOfEster: 4)]
        let result = try model.predict(doses: doses, at: [origin.addingTimeInterval(10 * 86_400)])
        let point = try #require(result.first)
        #expect(abs(point.estradiolPicogramsPerMilliliter - 262.69970356715885) < 1e-9)
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
        #expect(throws: ValeratePredictionError.self) {
            try model.predict(
                doses: [DoseAdministration(
                    timestamp: Date(timeIntervalSinceReferenceDate: .nan),
                    milligramsOfEster: 1
                )],
                at: [origin]
            )
        }
        #expect(throws: ValeratePredictionError.self) {
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
            #expect(throws: ValeratePredictionError.self) {
                try model.predict(doses: [DoseAdministration(timestamp: origin, milligramsOfEster: dose)], at: [origin])
            }
        }
        #expect(throws: ValeratePredictionError.self) {
            try model.predict(doses: [], at: [Date(timeIntervalSinceReferenceDate: .nan)])
        }
    }
}
