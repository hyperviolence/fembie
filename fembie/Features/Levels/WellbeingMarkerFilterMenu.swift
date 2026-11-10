import SwiftUI

struct WellbeingMarkerFilterMenu: View {
    @Binding var filter: WellbeingChartFilter
    let customSeries: [CustomWellbeingChartSeries]

    var body: some View {
        Menu {
            Toggle("Mood", isOn: $filter.showsMood)
            Toggle("Libido", isOn: $filter.showsLibido)
            Toggle("Energy", isOn: $filter.showsEnergy)
            if !customSeries.isEmpty {
                Section("Custom metrics") {
                    ForEach(customSeries) { series in
                        Toggle(series.label, isOn: Binding(
                            get: { filter.showsCustomMetric(id: series.id) },
                            set: { filter.setCustomMetric(id: series.id, isVisible: $0) }
                        ))
                    }
                }
            }
            Button("Show all") { filter = WellbeingChartFilter() }
        } label: {
            Label("Wellbeing markers", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }
}
