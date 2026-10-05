import SwiftUI
import Charts
import EstradiolPK

struct LevelsChart: View {
    let points: [PredictionPoint]
    let now: Date
    var showsRateOfChange = false
    var showWellbeing = false
    var wellbeing: [DailyCheckInAverage] = []

    var body: some View {
        VStack(alignment: .leading) {
            Chart {
                ForEach(points.filter { $0.timestamp <= now }, id: \.timestamp) { point in
                    if (point.timestamp == now) {
                        PointMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Value", showsRateOfChange
                                          ? point.rateOfChangePicogramsPerMilliliterPerHour
                                          : point.estradiolPicogramsPerMilliliter)
                            )
                            .symbol {
                                PulsingPoint()
                            }
                    } else {
                        LineMark(x: .value("Time", point.timestamp),
                                 y: .value("Value", showsRateOfChange
                                           ? point.rateOfChangePicogramsPerMilliliterPerHour
                                           : point.estradiolPicogramsPerMilliliter),
                                 series: .value("Period", "History"))
                        .foregroundStyle(.tint)
                    }
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
            .chartOverlay { proxy in
                if showWellbeing {
                    GeometryReader { geometry in
                        if let plotAnchor = proxy.plotFrame {
                            let plotFrame = geometry[plotAnchor]
                            if let start = proxy.value(atX: 0, as: Date.self),
                               let end = proxy.value(atX: plotFrame.width, as: Date.self),
                               start < end {
                                WellbeingOverlayChart(averages: wellbeing, dateRange: start...end)
                                    .frame(width: plotFrame.width, height: plotFrame.height)
                                    .position(x: plotFrame.midX, y: plotFrame.midY)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
            .chartYAxisLabel(showsRateOfChange ? "pg/mL/hour" : "pg/mL")
            .frame(minHeight: 220)
            .accessibilityLabel(showsRateOfChange ? "Estimated estradiol rate of change" : "Estimated estradiol levels")
            .accessibilityValue("Past fourteen days and next fourteen days. Dashed line shows projected levels.")
            if showWellbeing {
                LevelsWellbeingLegend(showsRateOfChange: showsRateOfChange)
            }
        }
    }
}
