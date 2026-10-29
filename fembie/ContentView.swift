import SwiftUI

struct ContentView: View {
    @Bindable var navigation: NotificationNavigationModel

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab("Levels", systemImage: "chart.xyaxis.line", value: .levels) {
                LevelsView()
            }
            Tab("Wellbeing", systemImage: "heart", value: .wellbeing) {
                CheckInView()
            }
            Tab("Labs", systemImage: "testtube.2", value: .labs) {
                LabResultsView()
            }
            Tab("Regimen", systemImage: "calendar", value: .regimen) {
                RegimenView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
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
        return ContentView(navigation: NotificationNavigationModel())
            .environment(RegimenViewModel(repository: repository))
            .environment(CheckInViewModel(repository: repository))
            .environment(LabResultsViewModel(repository: repository))
            .environment(DataExportViewModel(repository: repository))
            .environment(LevelsNotificationViewModel())
            .environment(CheckInReminderViewModel())
            .environment(RegimenNotificationViewModel())
    }
}
