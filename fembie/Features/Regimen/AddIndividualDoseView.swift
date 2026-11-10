import SwiftUI

struct AddIndividualDoseView: View {
    @Environment(RegimenViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var ester: EstradiolType = .estradiolEnanthate
    @State private var route: EstradiolRoute = .intramuscular
    @State private var color: RegimenColor?
    @State private var date = Date()
    @State private var dose = ""
    @State private var errorMessage: String?

    var body: some View {
        let formulations = EstradiolType.allCases.filter { type in
            EsterRoutes.getRoutes(ester: type).contains {
                LevelsPredictionCalculator.model(ester: type.displayName, route: $0) != nil
            }
        }
        let routes = EsterRoutes.getRoutes(ester: ester).filter {
            LevelsPredictionCalculator.model(ester: ester.displayName, route: $0) != nil
        }
        NavigationStack {
            Form {
                Section {
                    Picker("Formulation", selection: $ester) {
                        ForEach(formulations) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Route", selection: $route) {
                        ForEach(routes) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    DatePicker("Dose date", selection: $date)
                    TextField("Dose (mg)", text: $dose)
                        .keyboardType(.decimalPad)
                    Picker("Event color", selection: $color) {
                        Text("Default").tag(nil as RegimenColor?)
                        ForEach(RegimenColor.allCases) { option in
                            Label {
                                Text(option.label)
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(option.color)
                            }
                            .tag(Optional(option))
                        }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("Records one dose without creating a recurring regimen. Past doses are recorded as taken; future doses are scheduled.")
                }
                if ester == .estradiolGel {
                    Text("Enter milligrams of estradiol, not the weight of the gel.")
                        .font(.caption)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .disabled(model.isBusy)
            .navigationTitle("Add individual dose")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(model.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            do {
                                try await model.addStandaloneDose(ester: ester, route: route, date: date,
                                                                  doseText: dose, color: color)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(dose.isEmpty || model.isBusy)
                }
            }
            .interactiveDismissDisabled(model.isBusy)
            .onChange(of: ester) { _, value in
                if let firstRoute = EsterRoutes.getRoutes(ester: value).first(where: {
                    LevelsPredictionCalculator.model(ester: value.displayName, route: $0) != nil
                }) {
                    route = firstRoute
                }
            }
        }
    }
}
