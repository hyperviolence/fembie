import SwiftUI

struct LevelsWellbeingLegend: View {
    let showsRateOfChange: Bool
    var customSeries: [CustomWellbeingChartSeries] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(showsRateOfChange ? "dE2/dt" : "E2", systemImage: "line.diagonal")
                    .foregroundStyle(.tint)
                Label("Mood", systemImage: "circle.fill")
                    .foregroundStyle(.pink)
                Label("Libido", systemImage: "square.fill")
                    .foregroundStyle(.purple)
                Label("Energy", systemImage: "triangle.fill")
                    .foregroundStyle(.orange)
            }
            ForEach(customSeries) { series in
                Label(series.label, systemImage: "diamond.fill")
                    .foregroundStyle(series.color)
            }
        }
        .font(.caption)
    }
}
