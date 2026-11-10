import SwiftUI

struct LevelsWellbeingLegend: View {
    let showsRateOfChange: Bool
    var customSeries: [CustomWellbeingChartSeries] = []
    var filter = WellbeingChartFilter()

    var body: some View {
        let visibleCustomSeries = customSeries.filter { filter.showsCustomMetric(id: $0.id) }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(showsRateOfChange ? "dE2/dt" : "E2", systemImage: "line.diagonal")
                    .foregroundStyle(.tint)
                if filter.showsMood {
                    Label("Mood", systemImage: "circle.fill")
                        .foregroundStyle(.pink)
                }
                if filter.showsLibido {
                    Label("Libido", systemImage: "square.fill")
                        .foregroundStyle(.purple)
                }
                if filter.showsEnergy {
                    Label("Energy", systemImage: "triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            ForEach(visibleCustomSeries) { series in
                Label(series.label, systemImage: "diamond.fill")
                    .foregroundStyle(series.color)
            }
        }
        .font(.caption)
    }
}
