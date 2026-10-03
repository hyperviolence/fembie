import SwiftUI
import Charts
import EstradiolPK

struct LevelsChart: View {
    let points: [PredictionPoint]
    let now: Date
    var showsRateOfChange = false

    var body: some View {
        Chart {
            ForEach(points.filter { $0.timestamp <= now }, id: \.timestamp) { point in
                LineMark(x: .value("Time", point.timestamp),
                         y: .value("Value", showsRateOfChange
                            ? point.rateOfChangePicogramsPerMilliliterPerHour
                            : point.estradiolPicogramsPerMilliliter),
                         series: .value("Period", "History"))
                    .foregroundStyle(.tint)
            }
            ForEach(points.filter { $0.timestamp >= now }, id: \.timestamp) { point in
                LineMark(x: .value("Time", point.timestamp),
                         y: .value("Value", showsRateOfChange
                            ? point.rateOfChangePicogramsPerMilliliterPerHour
                            : point.estradiolPicogramsPerMilliliter),
                         series: .value("Period", "Projection"))
                    .foregroundStyle(.tint)
                    .lineStyle(StrokeStyle(dash: [5, 4]))
            }
            RuleMark(x: .value("Now", now))
                .foregroundStyle(.secondary)
        }
        .chartYAxisLabel(showsRateOfChange ? "pg/mL/hour" : "pg/mL")
        .frame(minHeight: 220)
        .accessibilityLabel(showsRateOfChange ? "Estimated estradiol rate of change" : "Estimated estradiol levels")
        .accessibilityValue("Past fourteen days and next fourteen days. Dashed line shows projected levels.")
    }
}
