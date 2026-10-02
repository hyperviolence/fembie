import SwiftUI

struct RegimenView: View {
    @State private var dose = ""
    @State private var intervalDays = ""
    @State private var firstInjection = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Regimen draft") {
                    LabeledContent("Formulation", value: "Estradiol enanthate")
                    LabeledContent("Route", value: "Subcutaneous")
                    TextField("Dose (mg of estradiol enanthate)", text: $dose)
                        .keyboardType(.decimalPad)
                    TextField("Interval (days)", text: $intervalDays)
                        .keyboardType(.decimalPad)
                    DatePicker("First injection", selection: $firstInjection)
                    Button("Save regimen") { }
                        .disabled(true)
                    Text("Draft fields only; scheduling and storage are not implemented.")
                        .foregroundStyle(.secondary)
                }
                Section("Injection events") {
                    ContentUnavailableView("No scheduled injections", systemImage: "calendar",
                        description: Text("Your schedule will generate the event list here."))
                }
                Section("Planned behavior") {
                    Text("Past events are assumed taken unless marked skipped or given a corrected time.")
                    Text("Moving one injection preserves the remaining schedule.")
                }
            }
            .navigationTitle("Regimen")
        }
    }
}
