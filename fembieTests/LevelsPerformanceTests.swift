import CoreGraphics
import EstradiolPK
import Foundation
import SwiftUI
import XCTest
@testable import fembie

private final class SendableExpectation: @unchecked Sendable {
    let value: XCTestExpectation

    init(description: String) {
        value = XCTestExpectation(description: description)
    }
}

final class LevelsPerformanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_893_456_000)

    func testFiveYearPredictionPerformance() throws {
        let regimen = try fiveYearRegimen()
        let calculator = LevelsPredictionCalculator()
        let predictionDate = now

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            // XCTest performance blocks are synchronous, so bridge the actor call
            // without making XCTestExpectation cross concurrency unsafely.
            let completion = SendableExpectation(description: "Prediction completes")

            Task {
                do {
                    let points = try await calculator.predict(
                        regimen: regimen,
                        now: predictionDate,
                        calibrationResult: nil,
                        alignSamplesToHour: false,
                        horizon: .chart
                    )
                    XCTAssertEqual(points.count, 673)
                } catch {
                    XCTFail("Prediction failed: \(error)")
                }
                completion.value.fulfill()
            }

            wait(for: [completion.value], timeout: 10)
        }
    }

    @MainActor
    func testLevelsChartsRenderingPerformance() async throws {
        let regimen = try fiveYearRegimen()
        let points = try await LevelsPredictionCalculator().predict(
            regimen: regimen,
            now: now,
            calibrationResult: nil,
            alignSamplesToHour: false,
            horizon: .chart
        )
        var renderedImage: CGImage?

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            let renderer = ImageRenderer(
                content: VStack {
                    LevelsChart(points: points, now: now)
                    LevelsChart(points: points, now: now, showsRateOfChange: true)
                }
                .frame(width: 400, height: 700)
                .background(.background)
            )
            renderer.scale = 1
            renderedImage = renderer.cgImage
        }

        XCTAssertNotNil(renderedImage)
    }

    private func fiveYearRegimen() throws -> Regimen {
        let effectiveFrom = now.addingTimeInterval(-5 * 365 * 86_400)
        let regimen = try Regimen(
            id: UUID(uuidString: "C5A2C76E-C37E-4F66-A8F9-70610BB46777") ?? UUID(),
            ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4,
            route: .intramuscular,
            intervalHours: 7 * 24,
            effectiveFrom: effectiveFrom,
            effectiveUntil: nil,
            timeZoneIdentifier: "UTC"
        )
        return try InjectionSchedule().extending(regimen, through: now)
    }
}
