import SwiftUI

@main
struct FemmeTrackApp: App {
    @State private var regimenModel: RegimenViewModel
    @State private var checkInModel: CheckInViewModel
    @State private var labResultsModel: LabResultsViewModel

    init() {
        let repository = FileTrackingRepository()
        _regimenModel = State(initialValue: RegimenViewModel(repository: repository))
        _checkInModel = State(initialValue: CheckInViewModel(repository: repository))
        _labResultsModel = State(initialValue: LabResultsViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(regimenModel)
                .environment(checkInModel)
                .environment(labResultsModel)
        }
    }
}
