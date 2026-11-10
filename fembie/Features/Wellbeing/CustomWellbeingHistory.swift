import SwiftUI
import Charts

struct CustomWellbeingHistory: View {
    let metrics: [CustomWellbeingRating]
    let dailyAverages: [DailyCheckInAverage]

    var body: some View {
        ForEach(metrics) { metric in
            Section {
                Chart(dailyAverages) { average in
                    if let rating = average.customRatings.first(where: { $0.id == metric.id }) {
                        LineMark(
                            x: .value("Date", average.date),
                            y: .value("Rating", rating.value)
                        )
                        .symbol(.circle)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 180)
                .accessibilityLabel(Text("Daily average \(metric.label)"))
                HStack(alignment: .top) {
                    Text("0: \(metric.lowLabel)")
                    Spacer()
                    Text("10: \(metric.highLabel)")
                        .multilineTextAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text(metric.label)
            }
        }
    }
}
