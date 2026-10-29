import Foundation
import CoreGraphics
import SwiftUI
import Testing
import EstradiolPK
@testable import fembie

struct LevelsPredictionCalculatorTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen() throws -> Regimen {
        let regimen = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 4, route: .intramuscular, intervalHours: 7 * 24, effectiveFrom: start,
            effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
        return try InjectionSchedule().extending(regimen, through: start.addingTimeInterval(14 * 86_400))
    }

    @MainActor @Test func wellbeingOverlayKeepsItsScaleAtHighEstradiolLevels() async throws {
        // Allow the regimen to reach steady state before the displayed 28-day window.
        let input = try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)",
            doseMilligramsOfEster: 29.2, route: .intramuscular, intervalHours: 7 * 24,
            effectiveFrom: start, effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
        let now = start.addingTimeInterval(84 * 86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let levels = points.map(\.estradiolPicogramsPerMilliliter).sorted()
        let median = try #require(levels.dropFirst(levels.count / 2).first)
        #expect((1_900...2_100).contains(median))

        let checkIns = (-7...0).map { day in
            CheckIn(id: UUID(), recordedAt: now.addingTimeInterval(Double(day) * 86_400),
                                mood: 5, libido: 8, energy: 2)
        }
        let renderer = ImageRenderer(content:
            LevelsChart(points: points, now: now, showWellbeing: true, wellbeing: checkIns)
                .frame(width: 400, height: 300)
                .background(.white)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)

        // Inspect the plotted lines, excluding the axes and the legend below the plot.
        // A shared E2 axis would squash all three scores against the bottom instead.
        let bands: [(Color, ClosedRange<Double>)] = [
            (.purple, 0.1...0.35), // libido 8: near the top
            (.pink, 0.3...0.6),    // mood 5: near the middle
            (.orange, 0.55...0.8) // energy 2: near the bottom
        ]
        for (color, band) in bands {
            let resolved = color.resolve(in: EnvironmentValues())
            var matchingPixels = 0
            for y in Int(band.lowerBound * Double(image.height))...Int(band.upperBound * Double(image.height)) {
                for x in (image.width / 3)...(image.width * 2 / 3) {
                    let offset = y * context.bytesPerRow + x * 4
                    if abs(Double(pixels[offset]) / 255 - Double(resolved.red)) < 0.08,
                       abs(Double(pixels[offset + 1]) / 255 - Double(resolved.green)) < 0.08,
                       abs(Double(pixels[offset + 2]) / 255 - Double(resolved.blue)) < 0.08 {
                        matchingPixels += 1
                    }
                }
            }
            #expect(matchingPixels > 50, "The \(color) wellbeing line should occupy its own 0–10 scale.")
        }
    }

    @Test func skippedAndMovedEventsUseEffectiveTimes() async throws {
        var input = try regimen()
        input.injectionEvents[0].adjustment = .skipped
        input.injectionEvents[1].adjustment = .moved(actualAt: start.addingTimeInterval(9 * 86_400))
        let now = start.addingTimeInterval(10 * 86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let current = try #require(points.first { $0.timestamp == now })
        let expected = try EnanthateIntramuscularModel().predict(
            doses: [DoseAdministration(timestamp: start.addingTimeInterval(9 * 86_400), milligramsOfEster: 4)], at: [now])
        #expect(abs(current.estradiolPicogramsPerMilliliter - expected[0].estradiolPicogramsPerMilliliter) < 1e-9)
        #expect(points.count == 673)
    }

    @Test func doseMovedIntoFutureCannotAffectCurrentEstimate() async throws {
        var input = try regimen()
        input.injectionEvents[0].adjustment = .moved(actualAt: start.addingTimeInterval(3 * 86_400))
        let now = start.addingTimeInterval(86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let current = try #require(points.first { $0.timestamp == now })
        #expect(current.estradiolPicogramsPerMilliliter == 0)
        #expect(points.last?.estradiolPicogramsPerMilliliter ?? 0 > 0)
    }

    @MainActor @Test func selectsModelFromSavedEsterAndRoute() async throws {
        let model = LevelsViewModel()
        var input = try regimen()
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: start)
        #expect(model.current != nil)
        #expect(model.modelIdentifier == EnanthateIntramuscularModel().modelIdentifier)
        #expect(model.message == nil)
        input.route = .subcutaneous
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: start)
        #expect(model.current != nil)
        #expect(model.points.count == 673)
        #expect(model.modelIdentifier == EnanthateSubcutaneousModel().modelIdentifier)
        #expect(model.message == nil)
        input.route = .intramuscular
        input.ester = "Estradiol Valerate (EV)"
        await model.refresh(input: LevelsPredictionInput(regimen: input), now: start)
        #expect(model.current == nil)
        #expect(model.message != nil)
    }

    @Test func unsupportedRoutesCannotUseIntramuscularCalculation() async throws {
        var input = try regimen()
        for route in EstradiolRoute.allCases where route != .intramuscular && route != .subcutaneous {
            input.route = route
            await #expect(throws: LevelsPredictionError.self) {
                try await LevelsPredictionCalculator().predict(regimen: input, now: start)
            }
        }
    }

    @Test func subcutaneousPredictionsUseAdjustedModel() async throws {
        var input = try regimen()
        input.route = .subcutaneous
        let now = start.addingTimeInterval(3 * 86_400)
        let points = try await LevelsPredictionCalculator().predict(regimen: input, now: now)
        let current = try #require(points.first { $0.timestamp == now })
        let expected = try EnanthateSubcutaneousModel().predict(
            doses: [DoseAdministration(timestamp: start, milligramsOfEster: 4)], at: [now])
        #expect(abs(current.estradiolPicogramsPerMilliliter - expected[0].estradiolPicogramsPerMilliliter) < 1e-9)
        #expect(abs(current.rateOfChangePicogramsPerMilliliterPerHour
            - expected[0].rateOfChangePicogramsPerMilliliterPerHour) < 1e-9)
    }

    @Test func detailPredictionCoversRegimenStartThroughNinetyDaysAhead() async throws {
        let input = try regimen()
        let now = start.addingTimeInterval(84 * 86_400)

        let points = try await LevelsPredictionCalculator().predict(
            regimen: input,
            now: now,
            horizon: .detail
        )

        #expect(points.first?.timestamp == input.effectiveFrom)
        #expect(points.last?.timestamp == now.addingTimeInterval(90 * 86_400))
        #expect(points.contains { $0.timestamp == now })
    }

    @Test func detailPredictionStopsWhenRegimenEnds() async throws {
        var input = try regimen()
        let now = start.addingTimeInterval(10 * 86_400)
        let regimenEnd = now.addingTimeInterval(30 * 86_400)
        input.effectiveUntil = regimenEnd

        let points = try await LevelsPredictionCalculator().predict(
            regimen: input,
            now: now,
            horizon: .detail
        )

        #expect(points.first?.timestamp == input.effectiveFrom)
        #expect(points.last?.timestamp == regimenEnd)
        #expect(points.allSatisfy { $0.timestamp <= regimenEnd })
    }

    @Test func correctionsInvalidatePlotIdentity() throws {
        let original = try regimen()
        var edited = original
        edited.injectionEvents[0].adjustment = .skipped
        #expect(LevelsPredictionInput(regimen: original) != LevelsPredictionInput(regimen: edited))
        edited = original
        edited.route = .subcutaneous
        #expect(LevelsPredictionInput(regimen: original) != LevelsPredictionInput(regimen: edited))
    }

    @Test func overlappingRegimensSumIndependentContributions() async throws {
        let intramuscular = try regimen()
        var transdermal = try Regimen(id: UUID(), ester: EstradiolType.estradiolEnanthate.displayName,
            doseMilligramsOfEster: 2, route: .intramuscular, intervalHours: 4 * 24,
            effectiveFrom: start, effectiveUntil: start.addingTimeInterval(14 * 86_400),
            timeZoneIdentifier: "UTC")
        transdermal = try InjectionSchedule().extending(transdermal,
            through: start.addingTimeInterval(14 * 86_400))
        let now = start.addingTimeInterval(7 * 86_400)
        let calculator = LevelsPredictionCalculator()
        let combined = try await calculator.predict(regimens: [intramuscular, transdermal], now: now,
            calibrationResult: nil, alignSamplesToHour: false, horizon: .chart)
        let combinedNow = try #require(combined.first { $0.timestamp == now })
        #expect(combinedNow.estradiolPicogramsPerMilliliter > 0)
        #expect(combined.contains { $0.timestamp > now })
    }
}
