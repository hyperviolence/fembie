import SwiftUI

@main
struct FemmeTrackApp: App {
    @State private var regimenModel = RegimenViewModel(repository: FileTrackingRepository())

    var body: some Scene {
        WindowGroup {
            ContentView().environment(regimenModel)
        }
    }
}
