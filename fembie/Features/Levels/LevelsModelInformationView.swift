import SwiftUI
import EstradiolPK

struct LevelsModelInformationView: View {
    let model: LevelsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Model") {
                    Text("Estimates include recorded history only, with untouched past doses assumed taken. Earlier doses and individual variability are not included.")
                        .foregroundStyle(.secondary)
                    if let modelIdentifier = model.modelIdentifier {
                        Text(modelIdentifier)
                            .font(.caption)
                    }
                    if model.modelIdentifier == TransdermalGelModel().modelIdentifier {
                        GelModelInformationSection()
                    } else {
                        if let sourceURL = URL(string: "https://estrannai.se") {
                            Link(model.modelSource, destination: sourceURL)
                        }
                        DisclosureGroup("MIT license · Copyright © 2025 alix") {
                            Text(EstrannaiseAttribution.license)
                                .font(.caption)
                        }
                    }
                    Text("Modeled estimates are not blood test measurements.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Model information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
