import Foundation
import Testing
@testable import EstradiolPK

struct EnanthateIntramuscularModelTests {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private let model = EnanthateIntramuscularModel()

    // Generated from the supplied Estrannaise models.js + modeldata.js, EEn im.
    @Test func matchesJavaScriptSingleDoseFixtures() throws {
        let days = [-1.0, 0, 1, 3, 7, 14]
        let expected = [0.0, 0, 4.731961545769717, 20.97174715650876,
                        31.177505115896995, 18.12449247179681]
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
        #expect(abs(point.estradiolPicogramsPerMilliliter - 189.950836542336) < 1e-9)
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
