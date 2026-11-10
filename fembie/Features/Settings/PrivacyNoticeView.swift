import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        ScrollView {
            Text("""
                fembie stores and processes your data locally by default. Notifications are scheduled on your device.

                If you manually enable iCloud Sync in Settings, your regimens, dose history, wellbeing check-ins, lab results, and saved preferences are also stored in your private iCloud account through Apple’s CloudKit service and synced to your other opted-in devices. Notification permission remains specific to each device.

                You can turn off sync at any time. This stops future syncs; it does not delete data already stored on your devices or in iCloud. fembie does not send your data to an analytics or advertising service.
                """)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle("Privacy notice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
