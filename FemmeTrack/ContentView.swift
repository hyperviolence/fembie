import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LevelsView()
                .tabItem { Label("Levels", systemImage: "chart.xyaxis.line") }
            CheckInView()
                .tabItem { Label("Wellbeing", systemImage: "heart") }
            RegimenView()
                .tabItem { Label("Regimen", systemImage: "calendar") }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
