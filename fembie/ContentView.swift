import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Levels", systemImage: "chart.xyaxis.line") {
                LevelsView()
            }
            Tab("Wellbeing", systemImage: "heart") {
                CheckInView()
            }
            Tab("Labs", systemImage: "testtube.2") {
                LabResultsView()
            }
            Tab("Regimen", systemImage: "calendar") {
                RegimenView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let repository = FileTrackingRepository(
            baseURL: URL.temporaryDirectory.appending(path: "FemmeTrackPreview-\(UUID())")
        )
        return ContentView()
            .environment(RegimenViewModel(repository: repository))
            .environment(CheckInViewModel(repository: repository))
            .environment(LabResultsViewModel(repository: repository))
            .environment(LevelsNotificationViewModel())
            .environment(CheckInReminderViewModel())
            .environment(RegimenNotificationViewModel())
    }
}
