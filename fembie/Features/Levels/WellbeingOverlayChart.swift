import SwiftUI

/// Draws within the E2 plot's frame, using its date range and an independent 0–10 scale.
struct WellbeingOverlayChart: View {
    let checkIns: [CheckIn]
    let dateRange: ClosedRange<Date>

    var body: some View {
        let firstVisibleIndex = checkIns.firstIndex {
            $0.recordedAt >= dateRange.lowerBound
        } ?? checkIns.endIndex
        let firstIndexAfterVisibleRange = checkIns.firstIndex {
            $0.recordedAt > dateRange.upperBound
        } ?? checkIns.endIndex
        let extendedStartIndex = firstVisibleIndex > checkIns.startIndex
            ? checkIns.index(before: firstVisibleIndex)
            : checkIns.startIndex
        let extendedEndIndex = firstIndexAfterVisibleRange < checkIns.endIndex
            ? checkIns.index(after: firstIndexAfterVisibleRange)
            : checkIns.endIndex
        let visibleCheckIns = checkIns[extendedStartIndex..<extendedEndIndex]

        Canvas { context, size in
            let duration = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
            guard duration > 0 else { return }
            let series: [(KeyPath<CheckIn, Double>, Color)] = [
                (\.mood, .pink), (\.libido, .purple), (\.energy, .orange)
            ]
            for (index, series) in series.enumerated() {
                let positions = visibleCheckIns.map { checkIn in
                    CGPoint(
                        x: checkIn.recordedAt.timeIntervalSince(dateRange.lowerBound) / duration * size.width,
                        y: (1 - checkIn[keyPath: series.0] / 10) * size.height
                    )
                }
                var line = Path()
                for (positionIndex, position) in positions.enumerated() {
                    if positionIndex == 0 { line.move(to: position) }
                    else { line.addLine(to: position) }
                }
                context.stroke(line, with: .color(series.1), lineWidth: 2)
                for position in positions {
                    let bounds = CGRect(x: position.x - 3, y: position.y - 3, width: 6, height: 6)
                    var symbol = Path()
                    switch index {
                    case 0:
                        symbol.addEllipse(in: bounds)
                    case 1:
                        symbol.addRect(bounds)
                    default:
                        symbol.move(to: CGPoint(x: position.x, y: bounds.minY))
                        symbol.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
                        symbol.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
                        symbol.closeSubpath()
                    }
                    context.fill(symbol, with: .color(series.1))
                }
            }
        }
        .accessibilityLabel("Mood, libido, and energy at recorded check-in times on a zero to ten scale")
        .accessibilityValue(visibleCheckIns.map { checkIn in
            "\(checkIn.recordedAt.formatted(date: .abbreviated, time: .shortened)): mood \(checkIn.mood.formatted()), libido \(checkIn.libido.formatted()), energy \(checkIn.energy.formatted())"
        }.joined(separator: ". "))
    }
}
