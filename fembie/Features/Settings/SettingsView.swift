import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
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
                    NavigationLink {
                        PrivacyNoticeView()
                    } label: {
                        Label("Privacy notice", systemImage: "hand.raised")
                    }
                }

                SettingsDataExportSection()
                SettingsDataResetSection()
            }
            .navigationTitle("Settings")
        }
    }
}
