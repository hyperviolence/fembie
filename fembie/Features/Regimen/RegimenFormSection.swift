import SwiftUI

struct RegimenFormSection: View {
    @Bindable var model: RegimenViewModel
    private let enabledTypes: Set<EstradiolType> = [.estradiolEnanthate]
    private let enabledRoutes: Set<EstradiolRoute> = [.intramuscular, .subcutaneous]

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
            TextField("Dose (mg)", text: $model.dose).keyboardType(.decimalPad)
            TextField("Interval (days)", text: $model.intervalDays).keyboardType(.decimalPad)
            DatePicker("First injection", selection: $model.firstInjection)
            Button("Save regimen") { Task { await model.saveRegimen() } }
                .disabled(!model.canSave)
        } header: {
            Text("Estradiol regimen")
        } footer: {
            if let message = model.validationMessage { Text(message) }
            else { Text("Saving replaces your previous regimen and its injection history.") }
        }
        .disabled(model.isBusy)
        .onChange(of: model.selectedEster) {
            if let route = EsterRoutes.getRoutes(ester: model.selectedEster).first(where: { enabledRoutes.contains($0) }) {
                model.selectedRoute = route
            }
        }
    }
}
