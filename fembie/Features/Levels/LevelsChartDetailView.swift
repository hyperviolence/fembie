import SwiftUI
import EstradiolPK

struct LevelsChartDetailView: View {
    @Environment(CheckInViewModel.self) private var checkInModel

    let input: LevelsPredictionInput
    let now: Date
    let showsRateOfChange: Bool

    @State private var model = LevelsViewModel()
    @State private var selectedDate: Date?
    @State private var mapsWellbeing: Bool

    init(
        input: LevelsPredictionInput,
        now: Date,
        showsRateOfChange: Bool,
        showWellbeing: Bool
    ) {
        self.input = input
        self.now = now
        self.showsRateOfChange = showsRateOfChange
        _mapsWellbeing = State(initialValue: showWellbeing)
    }

    var body: some View {
        VStack(alignment: .leading) {
            if !model.points.isEmpty {
                LevelsChart(
                    points: model.renderedPoints,
                    now: now,
                    showsRateOfChange: showsRateOfChange,
                    showWellbeing: mapsWellbeing,
                    wellbeing: checkInModel.checkIns,
                    isScrollable: true,
                    selectedPoint: model.selectedPoint,
                    selectedDate: $selectedDate
                )
                .frame(maxHeight: .infinity)

                LevelsWellbeingMappingControl(isEnabled: $mapsWellbeing)

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
        .task {
            await checkInModel.loadCheckIns()
        }
        .onChange(of: selectedDate) { _, newValue in
            model.selectPoint(nearestTo: newValue)
        }
    }
}
