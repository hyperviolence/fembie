import Foundation
import EstradiolPK

/// Finds every local turning point, rather than just the largest value in the window.
nonisolated struct LevelEventDetector {
    func events(in points: [PredictionPoint], kinds: Set<LevelNotificationKind>, after now: Date) -> [LevelNotificationEvent] {
        let points = points.sorted { $0.timestamp < $1.timestamp }
        guard points.count >= 3, points.allSatisfy({
            $0.estradiolPicogramsPerMilliliter.isFinite && $0.rateOfChangePicogramsPerMilliliterPerHour.isFinite
        }) else { return [] }
        var events: [LevelNotificationEvent] = []
        for kind in LevelNotificationKind.allCases where kinds.contains(kind) {
            let values = points.map { $0[keyPath: kind.value] }
            var index = 1
            while index < points.count - 1 {
                let first = index
                var last = index
                while last + 1 < points.count, equal(values[first], values[last + 1]) { last += 1 }
                guard last + 1 < points.count else { break }
                let left = values[first - 1]
                let middle = values[first]
                let right = values[last + 1]
                let isPeak = middle > left && middle > right && !equal(middle, left) && !equal(middle, right)
                let isLow = middle < left && middle < right && !equal(middle, left) && !equal(middle, right)
                if kind.isMaximum ? isPeak : isLow {
                    var timestamp = points[first].timestamp
                    // Refine isolated extrema with a parabola. Flat extrema notify once,
                    // when the plateau begins; constant curves produce no events.
                    let before = timestamp.timeIntervalSince(points[first - 1].timestamp)
                    let after = points[last + 1].timestamp.timeIntervalSince(timestamp)
                    if first == last, before > 0, abs(before - after) < 0.001 {
                        let denominator = left - 2 * middle + right
                        let offset = max(-0.5, min(0.5, 0.5 * (left - right) / denominator))
                        timestamp = timestamp.addingTimeInterval(offset * before)
                    }
                    timestamp = Date(timeIntervalSince1970: timestamp.timeIntervalSince1970.rounded())
                    if timestamp > now { events.append(LevelNotificationEvent(kind: kind, timestamp: timestamp)) }
                }
                index = last + 1
            }
        }
        return events.sorted {
            if $0.timestamp == $1.timestamp { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.timestamp < $1.timestamp
        }
    }

    private func equal(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= max(1, max(abs(lhs), abs(rhs))) * 1e-9
    }
}
