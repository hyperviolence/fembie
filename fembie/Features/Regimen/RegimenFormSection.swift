import SwiftUI

struct RegimenFormSection: View {
    @Bindable var model: RegimenViewModel
    private let enabledTypes: Set<EstradiolType> = [.estradiolEnanthate, .estradiolGel]
    private let enabledRoutes: Set<EstradiolRoute> = [.intramuscular, .subcutaneous, .transdermal]

    var body: some View {
        Section {
            Picker("Formulation", selection: $model.selectedEster) {
                ForEach(EstradiolType.allCases.filter { enabledTypes.contains($0) }) { ester in
                    Text(ester.displayName).tag(ester)
                }
            }
            Picker("Route", selection: $model.selectedRoute) {
                ForEach(EsterRoutes.getRoutes(ester: model.selectedEster).filter { enabledRoutes.contains($0) }) { route in
                    Text(route.displayName).tag(route)
                }
            }
            TextField(model.selectedEster == .estradiolGel ? "Estradiol per application (mg)" : "Dose (mg)", text: $model.dose)
                .keyboardType(.decimalPad)
            if model.selectedEster == .estradiolGel {
                Text("Enter the milligrams of estradiol contained in each gel application, not the weight of the gel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Interval unit", selection: $model.intervalUnit) {
                ForEach(RegimenIntervalUnit.allCases, id: \.self) { unit in
                    Text(unit.label).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            TextField(model.intervalUnit.fieldLabel, text: $model.interval).keyboardType(.decimalPad)
            DatePicker("First dose", selection: $model.firstInjection)
            Button("Save regimen") { Task { await model.saveRegimen() } }
                .disabled(!model.canSave)
        } header: {
            Text("Estradiol regimen")
        } footer: {
            if let message = model.validationMessage { Text(message) }
            else { Text("Saving replaces your previous regimen and its dose history.") }
        }
        .disabled(model.isBusy)
    }
}
