import Foundation
import Observation
import EstradiolPK

@MainActor
@Observable
final class LevelsViewModel {
    private(set) var modelIdentifier: String?
    private(set) var modelSource: String = "Model source loading..."
    private(set) var points: [PredictionPoint] = []
    private(set) var current: PredictionPoint?
    private(set) var message: String?
    private(set) var isLoading = false
    private(set) var calibrationMessage: String?
    private(set) var selectedPoint: PredictionPoint?
    private(set) var renderedPoints: [PredictionPoint] = []

    @ObservationIgnored private let calculator: any LevelsPredictionCalculating
    @ObservationIgnored private var revision = 0

    init(calculator: any LevelsPredictionCalculating = LevelsPredictionCalculator()) {
        self.calculator = calculator
    }

    func refresh(input: LevelsPredictionInput, now: Date = Date(),
                 horizon: LevelsPredictionHorizon = .chart) async {
        revision += 1
        let requestRevision = revision
        let isInitialLoad = current == nil
        isLoading = isInitialLoad
        if isInitialLoad {
            clearPrediction()
        }
        message = nil
        guard let regimen = input.regimen else {
            clearPrediction()
            isLoading = false
            message = "Save a regimen to see estimated levels."
            return
        }
        guard let predictionModel = LevelsPredictionCalculator.model(for: regimen) else {
            clearPrediction()
            isLoading = false
            message = LevelsPredictionError.unsupportedRegimen.localizedDescription
            return
        }
        modelIdentifier = predictionModel.modelIdentifier
        modelSource = predictionModel.modelSource
        defer {
            if revision == requestRevision { isLoading = false }
        }
        do {
            let result: [PredictionPoint]
            let updatedCalibrationMessage: String?
            do {
                result = try await calculator.predict(regimen: regimen, now: now,
                                                      calibrationResult: input.calibrationResult,
                                                      alignSamplesToHour: false, horizon: horizon)
                guard !Task.isCancelled, revision == requestRevision else { return }
                if let lab = input.calibrationResult {
                    updatedCalibrationMessage = "Adjusted using the E2 result from \(lab.recordedAt.formatted(date: .abbreviated, time: .shortened))."
                } else if input.calibrationEnabled {
                    updatedCalibrationMessage = "No E2 result is saved. Add an E2 result to apply calibration."
                } else {
                    updatedCalibrationMessage = nil
                }
            } catch LevelsPredictionError.invalidCalibration(let reason) {
                result = try await calculator.predict(regimen: regimen, now: now, calibrationResult: nil,
                                                      alignSamplesToHour: false, horizon: horizon)
                guard !Task.isCancelled, revision == requestRevision else { return }
                updatedCalibrationMessage = "Calibration not applied: \(reason)"
            }
            guard !Task.isCancelled, revision == requestRevision else { return }
            points = result
            renderedPoints = downsampledPoints(from: result, retaining: now)
            current = result.first { $0.timestamp == now }
            calibrationMessage = updatedCalibrationMessage
        } catch {
            guard !Task.isCancelled, revision == requestRevision else { return }
            message = "Could not calculate estimated levels: \(error.localizedDescription)"
        }
    }
    
    func selectPoint(nearestTo timestamp: Date?) {
        guard let timestamp, !points.isEmpty else {
            selectedPoint = nil
            return
        }

        let insertionIndex = lowerBound(for: timestamp)
        let nearestIndex: Int
        if insertionIndex == 0 {
            nearestIndex = 0
        } else if insertionIndex == points.count {
            nearestIndex = points.index(before: points.endIndex)
        } else {
            let previousIndex = points.index(before: insertionIndex)
            let previousDistance = abs(points[previousIndex].timestamp.timeIntervalSince(timestamp))
            let nextDistance = abs(points[insertionIndex].timestamp.timeIntervalSince(timestamp))
            nearestIndex = previousDistance <= nextDistance ? previousIndex : insertionIndex
        }

        guard selectedPoint?.timestamp != points[nearestIndex].timestamp else { return }
        selectedPoint = points[nearestIndex]
    }

    private func clearPrediction() {
        points = []
        current = nil
        calibrationMessage = nil
        selectedPoint = nil
        renderedPoints = []
        modelIdentifier = nil
    }

    private func downsampledPoints(
        from source: [PredictionPoint],
        retaining retainedTimestamp: Date
    ) -> [PredictionPoint] {
        let pointLimit = 3_000
        guard source.count > pointLimit else { return source }

        // Preserve each bucket's endpoints and extrema for both chart modes.
        let bucketCount = max(1, pointLimit / 6)
        let bucketSize = Int(ceil(Double(source.count) / Double(bucketCount)))
        var retainedIndices: Set<Int> = [source.startIndex, source.index(before: source.endIndex)]

        for bucketStart in stride(from: source.startIndex, to: source.endIndex, by: bucketSize) {
            let bucketEnd = min(bucketStart + bucketSize, source.endIndex)
            let indices = bucketStart..<bucketEnd
            guard let lastIndex = indices.last else { continue }

            retainedIndices.insert(bucketStart)
            retainedIndices.insert(lastIndex)
            if let minimumLevel = indices.min(by: {
                source[$0].estradiolPicogramsPerMilliliter
                    < source[$1].estradiolPicogramsPerMilliliter
            }) {
                retainedIndices.insert(minimumLevel)
            }
            if let maximumLevel = indices.max(by: {
                source[$0].estradiolPicogramsPerMilliliter
                    < source[$1].estradiolPicogramsPerMilliliter
            }) {
                retainedIndices.insert(maximumLevel)
            }
            if let minimumRate = indices.min(by: {
                source[$0].rateOfChangePicogramsPerMilliliterPerHour
                    < source[$1].rateOfChangePicogramsPerMilliliterPerHour
            }) {
                retainedIndices.insert(minimumRate)
            }
            if let maximumRate = indices.max(by: {
                source[$0].rateOfChangePicogramsPerMilliliterPerHour
                    < source[$1].rateOfChangePicogramsPerMilliliterPerHour
            }) {
                retainedIndices.insert(maximumRate)
            }
        }

        let retainedIndex = lowerBound(for: retainedTimestamp)
        if retainedIndex < source.endIndex, source[retainedIndex].timestamp == retainedTimestamp {
            retainedIndices.insert(retainedIndex)
        }

        return retainedIndices.sorted().map { source[$0] }
    }

    private func lowerBound(for timestamp: Date) -> Int {
        var lowerIndex = points.startIndex
        var upperIndex = points.endIndex

        while lowerIndex < upperIndex {
            let middleIndex = lowerIndex + (upperIndex - lowerIndex) / 2
            if points[middleIndex].timestamp < timestamp {
                lowerIndex = middleIndex + 1
            } else {
                upperIndex = middleIndex
            }
        }
        return lowerIndex
    }
}
