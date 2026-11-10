import SwiftUI

/// Shared identities and colors keep the overlay and its legend in agreement.
struct CustomWellbeingChartSeries: Identifiable {
    let id: UUID
    let label: String
    let color: Color
    let samples: [(date: Date, value: Double)]

    static func make(from checkIns: [CheckIn]) -> [Self] {
        let ordered = checkIns.sorted { $0.recordedAt < $1.recordedAt }
        var metrics: [UUID: CustomWellbeingRating] = [:]
        var samples: [UUID: [(date: Date, value: Double)]] = [:]
        for checkIn in ordered {
            for rating in checkIn.customRatings where rating.value.isFinite && (0...10).contains(rating.value) {
                metrics[rating.id] = rating
                samples[rating.id, default: []].append((checkIn.recordedAt, rating.value))
            }
        }
        let palette: [Color] = [.teal, .green, .indigo, .cyan, .brown, .red]
        return metrics.values.sorted { $0.id.uuidString < $1.id.uuidString }.map { metric in
            // Unlike hashValue, this mapping stays the same between launches and devices.
            let colorIndex = metric.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % palette.count }
            return Self(id: metric.id, label: metric.label, color: palette[colorIndex],
                        samples: samples[metric.id] ?? [])
        }
    }

    /// Include a neighboring sample on either side so scrolling does not cut connecting lines.
    func visibleSamples(in range: ClosedRange<Date>) -> [(date: Date, value: Double)] {
        let first = samples.firstIndex { $0.date >= range.lowerBound } ?? samples.endIndex
        let end = samples.firstIndex { $0.date > range.upperBound } ?? samples.endIndex
        return Array(samples[max(0, first - 1)..<min(samples.count, end + 1)])
    }
}
