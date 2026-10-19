import SwiftUI
import Charts
import EstradiolPK

struct LevelsChart: View {
    let points: [PredictionPoint]
    let now: Date
    var showsRateOfChange = false
    var showWellbeing = false
    var wellbeing: [CheckIn] = []
    var isScrollable = false
    var selectedPoint: PredictionPoint? = nil
    var selectedDate: Binding<Date?>? = nil

    var body: some View {
        VStack(alignment: .leading) {
            Chart {
                ForEach(points.filter { $0.timestamp <= now }, id: \.timestamp) { point in
                    LineMark(x: .value("Time", point.timestamp),
                             y: .value("Value", showsRateOfChange
                                       ? point.rateOfChangePicogramsPerMilliliterPerHour
                                       : point.estradiolPicogramsPerMilliliter),
                             series: .value("Period", "History"))
                    .foregroundStyle(.tint)
                    if point.timestamp == now, selectedPoint == nil {
                        PointMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Value", showsRateOfChange
                                          ? point.rateOfChangePicogramsPerMilliliterPerHour
                                          : point.estradiolPicogramsPerMilliliter)
                            )
                            .symbol {
                                PulsingPoint()
                            }
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
                if let selectedPoint {
                    let selectedValue = showsRateOfChange
                        ? selectedPoint.rateOfChangePicogramsPerMilliliterPerHour
                        : selectedPoint.estradiolPicogramsPerMilliliter
                    RuleMark(x: .value("Selected time", selectedPoint.timestamp))
                        .foregroundStyle(.secondary)
                    PointMark(
                        x: .value("Selected time", selectedPoint.timestamp),
                        y: .value("Selected value", selectedValue)
                    )
                    .symbol {
                        PulsingPoint()
                    }
                    .annotation(position: .top) {
                        VStack {
                            Text(selectedPoint.timestamp, format: .dateTime.month().day().year().hour().minute())
                            if showsRateOfChange {
                                Text("\(selectedValue, format: .number.precision(.fractionLength(1))) pg/mL/hour")
                                    .bold()
                            } else {
                                Text("\(selectedValue, format: .number.precision(.fractionLength(1))) pg/mL")
                                    .bold()
                            }
                        }
                        .font(.caption)
                        .padding()
                        //.background(.regularMaterial, in: .rect(cornerRadius: 8))
                    }
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
                                WellbeingOverlayChart(checkIns: wellbeing, dateRange: start...end)
                                    .frame(width: plotFrame.width, height: plotFrame.height)
                                    .position(x: plotFrame.midX, y: plotFrame.midY)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
            .chartYAxisLabel(showsRateOfChange ? "pg/mL/hour" : "pg/mL")
            .modifier(LevelsChartScrollingModifier(isEnabled: isScrollable, now: now))
            .modifier(LevelsChartSelectionModifier(selection: selectedDate))
            .frame(minHeight: 220)
            .accessibilityLabel(showsRateOfChange ? "Estimated estradiol rate of change" : "Estimated estradiol levels")
            .accessibilityValue("Past fourteen days and next fourteen days. Dashed line shows projected levels.")
            if showWellbeing {
                LevelsWellbeingLegend(showsRateOfChange: showsRateOfChange)
            }
        }
    }
}

private struct LevelsChartScrollingModifier: ViewModifier {
    let isEnabled: Bool
    let now: Date

    private let visibleDuration: TimeInterval = 7 * 86_400

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleDuration)
                .chartScrollPosition(initialX: now.addingTimeInterval(-visibleDuration / 2))
        } else {
            content
        }
    }
}

private struct LevelsChartSelectionModifier: ViewModifier {
    let selection: Binding<Date?>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let selection {
            content.chartXSelection(value: selection)
        } else {
            content
        }
    }
}
