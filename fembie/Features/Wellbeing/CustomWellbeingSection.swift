import SwiftUI

struct CustomWellbeingSection: View {
    @Environment(CheckInViewModel.self) private var model
    @Binding var isAddingMetric: Bool

    var body: some View {
        @Bindable var model = model
        Section {
            ForEach($model.customRatings) { $rating in
                VStack(alignment: .leading) {
                    LabeledContent(rating.label, value: rating.value.formatted())
                    Slider(value: $rating.value, in: 0...10, step: 1)
                        .accessibilityLabel(rating.label)
                    HStack(alignment: .top) {
                        Text(rating.lowLabel)
                        Spacer()
                        Text(rating.highLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        let id = rating.id
                        Task { await model.deleteCustomMetric(id: id) }
                    }
                }
            }
            if let error = model.metricDeletionError {
                Text(error)
                    .foregroundStyle(.red)
            }
            Button("Add custom metric", systemImage: "plus") {
                isAddingMetric = true
            }
        } header: {
            Text("Custom metrics")
        } footer: {
            Text("Use a 0–10 scale. New metrics and their labels are stored when you save a check-in.")
        }
        .disabled(model.isBusy)

    }
}
