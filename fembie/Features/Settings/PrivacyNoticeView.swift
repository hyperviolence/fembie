import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        ScrollView {
            Text("""
                All data collected by fembie, including push notifications, is stored and processed locally on user's device. Nothing gets shared with third-party, with no intentions of doing so in future.
                Any future possibility of storing the user's data in iCloud will be optional, and the user will need to opt-in to have this feature enabled.
                """)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle("Privacy notice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
