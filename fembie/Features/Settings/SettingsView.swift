import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    AboutFembieView()
                } label: {
                    Label("About fembie...", systemImage: "info.circle")
                }
                NavigationLink {
                    SafetyNoticeView()
                } label: {
                    Label("Safety notice", systemImage: "exclamationmark.shield")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
