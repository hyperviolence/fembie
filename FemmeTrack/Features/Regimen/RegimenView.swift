import SwiftUI

struct RegimenView: View {
    @Environment(RegimenViewModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                if let error = model.loadError {
                    Section {
                        Text(error).foregroundStyle(.red)
                        Button("Retry loading") { Task { await model.load() } }
                            .disabled(model.isBusy)
                    }
                }
                RegimenFormSection(model: model)
                RegimenSummarySection(regimen: model.savedRegimen, title: model.regimenTitle)
                InjectionEventsSection(model: model)
            }
            .navigationTitle("Regimen")
            .task(id: scenePhase) {
                if scenePhase == .active { await model.load() }
            }
            .task {
                // Keep upcoming/assumed status current while the screen remains open.
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(30)) }
                    catch { return }
                    model.refreshTime()
                }
            }
            .alert("Regimen", isPresented: $model.showAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text(model.alertMessage) }
        }
    }
}
