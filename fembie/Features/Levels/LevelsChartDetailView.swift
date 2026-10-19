import SwiftUI
import EstradiolPK

struct LevelsChartDetailView: View {
    let input: LevelsPredictionInput
    let now: Date
    let showsRateOfChange: Bool
    let showWellbeing: Bool
    let wellbeing: [CheckIn]

    @State private var model = LevelsViewModel()
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading) {
            if !model.points.isEmpty {
                LevelsChart(
                    points: model.renderedPoints,
                    now: now,
                    showsRateOfChange: showsRateOfChange,
                    showWellbeing: showWellbeing,
                    wellbeing: wellbeing,
                    isScrollable: true,
                    selectedPoint: model.selectedPoint,
                    selectedDate: $selectedDate
                )
                .frame(maxHeight: .infinity)

                Text("Swipe horizontally to explore from the start of the regimen through the next 90 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let message = model.message {
                ContentUnavailableView(
                    "No estimate available",
                    systemImage: "chart.xyaxis.line",
                    description: Text(message)
                )
            } else {
                ProgressView("Calculating extended estimate")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .navigationTitle(showsRateOfChange ? "Rate of change" : "Estimated estradiol")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: input) {
            await model.refresh(input: input, now: now, horizon: .detail)
        }
        .onChange(of: selectedDate) { _, newValue in
            model.selectPoint(nearestTo: newValue)
        }
    }
}
