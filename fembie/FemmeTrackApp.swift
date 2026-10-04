import SwiftUI

@main
struct FemmeTrackApp: App {
    @State private var regimenModel: RegimenViewModel
    @State private var checkInModel: CheckInViewModel

    init() {
        let repository = FileTrackingRepository()
        _regimenModel = State(initialValue: RegimenViewModel(repository: repository))
        _checkInModel = State(initialValue: CheckInViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(regimenModel)
                .environment(checkInModel)
        }
    }
}
