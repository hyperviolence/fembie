import Foundation
import Testing
import EstradiolPK
@testable import fembie

struct LevelsCalibrationTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func regimen() throws -> Regimen {
        try Regimen(id: UUID(), ester: "Estradiol Enanthate (EEn)", doseMilligramsOfEster: 10,
                    route: .intramuscular, intervalHours: 168, effectiveFrom: start,
                    effectiveUntil: nil, timeZoneIdentifier: "Europe/Istanbul")
    }

    @Test func subtractsTwoHundredAfterTheExactMeasurementTime() async throws {
        let regimen = try regimen()
        let calculator = LevelsPredictionCalculator()
        let labDate = start.addingTimeInterval(3 * 86400 + 1800)
        let now = labDate.addingTimeInterval(86400 + 900)
        let reference = try await calculator.predict(regimen: regimen, now: labDate)
        let baseline = try #require(reference.first { $0.timestamp == labDate })
        #expect(baseline.estradiolPicogramsPerMilliliter > 200)
        let lab = LabResult(id: UUID(), test: .e2,
                            value: baseline.estradiolPicogramsPerMilliliter - 200, recordedAt: labDate)
        let raw = try await calculator.predict(regimen: regimen, now: now)
        let adjusted = try await calculator.predict(regimen: regimen, now: now, calibrationResult: lab)
        let anchored = try #require(adjusted.first { $0.timestamp == labDate })
        #expect(abs(anchored.estradiolPicogramsPerMilliliter - lab.value) < 1e-9)
        let adjustedByDate = Dictionary(uniqueKeysWithValues: adjusted.map { ($0.timestamp, $0) })
        for point in raw {
            let actual = try #require(adjustedByDate[point.timestamp])
            let expected = point.timestamp < labDate ? point.estradiolPicogramsPerMilliliter
                : max(0, point.estradiolPicogramsPerMilliliter - 200)
            #expect(abs(actual.estradiolPicogramsPerMilliliter - expected) < 1e-9)
            let expectedRate = point.timestamp >= labDate && expected == 0
                ? 0 : point.rateOfChangePicogramsPerMilliliterPerHour
            #expect(actual.rateOfChangePicogramsPerMilliliterPerHour == expectedRate)
        }
    }

    @Test func supportsPositiveOffsetsAndTurningCalibrationOff() async throws {
        let regimen = try regimen()
        let calculator = LevelsPredictionCalculator()
        let date = start.addingTimeInterval(3 * 86400)
        let raw = try await calculator.predict(regimen: regimen, now: date)
        let baseline = try #require(raw.first { $0.timestamp == date })
        let lab = LabResult(id: UUID(), test: .e2,
                            value: baseline.estradiolPicogramsPerMilliliter + 50, recordedAt: date)
        let adjusted = try await calculator.predict(regimen: regimen, now: date, calibrationResult: lab)
        for (before, after) in zip(raw, adjusted) where before.timestamp >= date {
            #expect(abs(after.estradiolPicogramsPerMilliliter - before.estradiolPicogramsPerMilliliter - 50) < 1e-9)
            #expect(after.rateOfChangePicogramsPerMilliliterPerHour == before.rateOfChangePicogramsPerMilliliterPerHour)
        }
        let restored = try await calculator.predict(regimen: regimen, now: date, calibrationResult: nil)
        #expect(restored.map(\.estradiolPicogramsPerMilliliter) == raw.map(\.estradiolPicogramsPerMilliliter))
    }

    @MainActor @Test func invalidCalibrationKeepsTheOriginalGraphAvailable() async throws {
        let regimen = try regimen()
        let now = start.addingTimeInterval(5 * 86400)
        let futureLab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: now.addingTimeInterval(86400))
        let model = LevelsViewModel()
        await model.refresh(input: LevelsPredictionInput(regimen: regimen, calibrationResult: futureLab), now: now)
        let raw = try await LevelsPredictionCalculator().predict(regimen: regimen, now: now)
        #expect(model.points.map(\.estradiolPicogramsPerMilliliter) == raw.map(\.estradiolPicogramsPerMilliliter))
        #expect(model.current != nil)
        #expect(model.calibrationMessage?.contains("not applied") == true)
    }

    @Test func labChangesInvalidateThePredictionInput() throws {
        let regimen = try regimen()
        let date = start.addingTimeInterval(86400)
        let lab = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: date)
        let edited = LabResult(id: lab.id, test: .e2, value: 250, recordedAt: date)
        #expect(LevelsPredictionInput(regimen: regimen) != LevelsPredictionInput(regimen: regimen, calibrationResult: lab))
        #expect(LevelsPredictionInput(regimen: regimen, calibrationResult: lab)
                != LevelsPredictionInput(regimen: regimen, calibrationResult: edited))
    }

    @MainActor @Test func calibrationUsesTheNewestE2RegardlessOfOtherLabResults() async throws {
        let directory = URL.temporaryDirectory.appending(path: "LevelsCalibrationTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileTrackingRepository(baseURL: directory)
        let older = LabResult(id: UUID(), test: .e2, value: 200, recordedAt: start)
        let newer = LabResult(id: UUID(), test: .e2, value: 250, recordedAt: start.addingTimeInterval(86400))
        let unrelated = LabResult(id: UUID(), test: .lh, value: 5, recordedAt: start.addingTimeInterval(2 * 86400))
        for lab in [newer, older, unrelated] { try await repository.save(lab) }
        let model = LabResultsViewModel(repository: repository)
        await model.load()
        #expect(model.latestE2Result?.id == newer.id)
    }
}
