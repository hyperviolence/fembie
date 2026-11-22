import StoreKit
import SwiftUI

struct DonationView: View {
    private static let donationProductID = "com.hyperviolet.fembie.donation.small"

    var body: some View {
        Form {
            Section {
                Text("If fembie is useful to you, you can make a small, optional donation to support its development.")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("This is only a donation. It does not unlock features, remove limits, or change anything in the app.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ProductView(id: Self.donationProductID)
            } header: {
                Text("One-time donation")
            } footer: {
                Text("The amount and currency are shown by Apple before you confirm. Donations are processed as an in-app purchase.")
            }
        }
        .navigationTitle("Support fembie")
        .navigationBarTitleDisplayMode(.inline)
    }
}
