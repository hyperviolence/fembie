import Foundation
import SwiftUI
import Testing
@testable import fembie

@MainActor
struct CustomWellbeingChartSeriesTests {
    @Test func seriesPreserveIdentityAndRecordedValuesWithoutFillingMissingAnswers() throws {
        let id = UUID()
        let earlier = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 100), mood: 1, libido: 2, energy: 3,
                              customRatings: [.init(id: id, label: "Sleep", lowLabel: "Poor", highLabel: "Restful", value: 4)])
        let missing = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 200), mood: 1, libido: 2, energy: 3)
        let later = CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: 300), mood: 1, libido: 2, energy: 3,
                            customRatings: [.init(id: id, label: "Sleep quality", lowLabel: "Poor", highLabel: "Restful", value: 8)])
        let series = try #require(CustomWellbeingChartSeries.make(from: [later, missing, earlier]).first)
        #expect(series.id == id)
        #expect(series.label == "Sleep quality")
        #expect(series.samples.map(\.date) == [earlier.recordedAt, later.recordedAt])
        #expect(series.samples.map(\.value) == [4, 8])
        let isolated = try #require(CustomWellbeingChartSeries.make(from: [later]).first)
        #expect(series.color == isolated.color)
        #expect(CustomWellbeingChartSeries.make(from: [missing]).isEmpty)
    }

    @Test func sameLabelsDoNotMergeDifferentMetrics() {
        let checkIn = CheckIn(id: UUID(), recordedAt: .now, mood: 1, libido: 2, energy: 3,
                              customRatings: [
                                .init(id: UUID(), label: "Sleep", lowLabel: "Low", highLabel: "High", value: 4),
                                .init(id: UUID(), label: "Sleep", lowLabel: "Low", highLabel: "High", value: 8)
                              ])
        let series = CustomWellbeingChartSeries.make(from: [checkIn])
        #expect(series.count == 2)
        #expect(Set(series.flatMap { $0.samples.map(\.value) }) == [4, 8])
    }

    @Test func scrollingIncludesNeighborsForSparseMetrics() throws {
        let id = UUID()
        let checkIns = [0.0, 100, 200, 300].map { time in
            CheckIn(id: UUID(), recordedAt: Date(timeIntervalSince1970: time), mood: 1, libido: 2, energy: 3,
                    customRatings: [.init(id: id, label: "Sleep", lowLabel: "Low", highLabel: "High", value: 5)])
        }
        let series = try #require(CustomWellbeingChartSeries.make(from: checkIns).first)
        let samples = series.visibleSamples(in: Date(timeIntervalSince1970: 120)...Date(timeIntervalSince1970: 180))
        #expect(samples.map(\.date) == [checkIns[1].recordedAt, checkIns[2].recordedAt])
        #expect(series.visibleSamples(in: Date(timeIntervalSince1970: -20)...Date(timeIntervalSince1970: -10)).count == 1)
        #expect(series.visibleSamples(in: Date(timeIntervalSince1970: 400)...Date(timeIntervalSince1970: 500)).count == 1)
        let empty = CustomWellbeingChartSeries(id: id, label: "Empty", color: .teal, samples: [])
        #expect(empty.visibleSamples(in: .distantPast ... .distantFuture).isEmpty)
    }
}
