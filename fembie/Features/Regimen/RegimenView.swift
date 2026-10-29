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
                RegimenSummarySection(regimen: model.savedRegimen, title: model.regimenTitle)
                Section("Dose events") {
                    if model.hasMorePast {
                        Button("Show more past doses…", action: model.showMorePast)
                    }
                    ForEach(model.visibleEvents) { event in
                        InjectionEventRow(model: model, event: event)
                    }
                    if model.visibleEvents.isEmpty {
                        ContentUnavailableView("No scheduled doses", systemImage: "calendar",
                                               description: Text("Save a regimen to generate your dose schedule."))
                    }
                    if model.hasMoreFuture {
                        Button("Show more future doses…") { Task { await model.showMoreFuture() } }
                    }
                }
                RegimenFormSection(model: model)
                RegimenNotificationSection()
            }
            .navigationTitle("Regimen")
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await model.load()

                // Refresh while active; a phase change cancels this task.
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
