import SwiftUI

struct SettingsICloudSyncSection: View {
    @Environment(ICloudSyncViewModel.self) private var model
    @State private var confirmCloudDeletion = false

    var body: some View {
        Section {
            Toggle("iCloud Sync", isOn: Binding(get: { model.enabled }, set: { model.setEnabled($0) }))
            .disabled(model.isDeleting)
            if model.enabled {
                if model.isSyncing {
                    ProgressView("Syncing…")
                } else {
                    Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await model.sync() }
                    }
                }
                if let date = model.lastSynced {
                    LabeledContent("Last synced") {
                        Text(date, format: .dateTime.month().day().hour().minute())
                    }
                }
            }
            Button("Delete data from iCloud…", systemImage: "trash", role: .destructive) {
                confirmCloudDeletion = true
            }
            .disabled(model.isSyncing || model.isDeleting)
            .confirmationDialog("Delete data from iCloud?", isPresented: $confirmCloudDeletion,
                                titleVisibility: .visible) {
                Button("Delete data from iCloud", role: .destructive) {
                    Task { await model.deleteCloudData() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes all fembie data stored in your iCloud account and turns off sync on this device. Local data is kept. Turn off sync on your other devices to prevent them from uploading data again. This cannot be undone.")
            }
            if model.isDeleting {
                ProgressView("Deleting iCloud data…")
            } else if model.deletionCompleted {
                Text("iCloud data deleted. Local data is kept.")
            }
            if let message = model.errorMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Sync regimens, dose history, wellbeing check-ins, lab results, and preferences with your private iCloud account while fembie is open. Enable this on each device. If the same entry changes on two devices, the version already in iCloud wins. Turning sync off keeps your data on this device and in iCloud.")
        }
    }
}
