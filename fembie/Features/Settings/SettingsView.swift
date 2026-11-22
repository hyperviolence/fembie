import SwiftUI

struct SettingsView: View {
    @Binding var isPresentingTutorial: Bool

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
                        DonationView()
                    } label: {
                        Label("Make a donation", systemImage: "heart")
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

                Section("Help") {
                    Button("Show tutorial again", systemImage: "questionmark.circle") {
                        isPresentingTutorial = true
                    }
                }

                SettingsICloudSyncSection()
                SettingsDataExportSection()
                SettingsDataResetSection()
            }
            .navigationTitle("Settings")
        }
    }
}
