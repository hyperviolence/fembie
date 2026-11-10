import SwiftUI

#Preview {
    AddWellbeingMetricView()
        .environment(CheckInViewModel(repository: FileTrackingRepository()))
}


struct AddWellbeingMetricView: View {
    @Environment(CheckInViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var lowLabel = ""
    @State private var highLabel = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Metric") {
                    TextField("Name", text: $label, prompt: Text("For example, Sleep quality"))
                }
                Section {
                    TextField("Label at 0", text: $lowLabel, prompt: Text("For example, Very poor"))
                    TextField("Label at 10", text: $highLabel, prompt: Text("For example, Very restful"))
                } header: {
                    Text("Scale labels")
                } footer: {
                    Text("Each label can contain up to 100 characters.")
                }
                if let error = model.metricError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add custom metric")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if model.addCustomMetric(label: label, lowLabel: lowLabel, highLabel: highLabel) {
                            dismiss()
                        }
                    }
                    .disabled(model.isBusy)
                }
            }
        }
    }
}
