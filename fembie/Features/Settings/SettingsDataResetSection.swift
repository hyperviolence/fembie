import SwiftUI

struct SettingsDataResetSection: View {
    @Environment(RegimenViewModel.self) private var regimen
    @Environment(CheckInViewModel.self) private var wellbeing
    @Environment(LevelsNotificationViewModel.self) private var notifications
    @State private var confirmRegimenReset = false
    @State private var confirmWellbeingReset = false
    @State private var isResetting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var completionMessage: String?

    var body: some View {
        Section {
            Button("Reset regimen data...", systemImage: "trash", role: .destructive) {
                confirmRegimenReset = true
            }
            .disabled(isResetting || regimen.isBusy)
            .confirmationDialog("Reset regimen data?", isPresented: $confirmRegimenReset,
                                titleVisibility: .visible) {
                Button("Reset regimen data", role: .destructive) {
                    reset(regimenData: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes your saved regimen and all injection history and adjustments, and cancels its level alerts. This cannot be undone.")
            }

            Button("Reset wellbeing data...", systemImage: "trash", role: .destructive) {
                confirmWellbeingReset = true
            }
            .disabled(isResetting || wellbeing.isBusy)
            .confirmationDialog("Reset wellbeing data?", isPresented: $confirmWellbeingReset,
                                titleVisibility: .visible) {
                Button("Reset wellbeing data", role: .destructive) {
                    reset(regimenData: false)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes all your wellbeing check-ins, including mood, libido, and energy history. This cannot be undone.")
            }
        } footer: {
            if isResetting {
                Text("Resetting data…")
            } else if let completionMessage {
                Text(completionMessage)
            }
        }
        .alert("Could not reset data", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func reset(regimenData: Bool) {
        guard !isResetting else { return }
        isResetting = true
        completionMessage = nil
        Task {
            defer { isResetting = false }
            do {
                if regimenData {
                    try await regimen.resetData()
                    await notifications.refresh(input: LevelsPredictionInput(regimen: nil))
                    completionMessage = "Regimen data reset."
                } else {
                    try await wellbeing.resetData()
                    completionMessage = "Wellbeing data reset."
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
