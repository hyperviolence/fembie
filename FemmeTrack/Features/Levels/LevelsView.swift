import SwiftUI
import EstradiolPK

struct LevelsView: View {
    private let model = EnanthateSubcutaneousModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Estimated estradiol") {
                    ContentUnavailableView("No prediction yet", systemImage: "chart.xyaxis.line",
                        description: Text("The research-backed model is not implemented yet."))
                }
                Section("Rate of change · dE2/dt") {
                    Text("The rate-of-change graph will appear here.")
                        .foregroundStyle(.secondary)
                }
                Section("Model") {
                    Text(model.modelIdentifier)
                    Text("Scheduled injections and corrections will drive both graphs.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Levels")
        }
    }
}
