import SwiftUI

struct RegimenNotificationSection: View {
    @Environment(RegimenNotificationViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section {
            Toggle("Remind me before a dose", isOn: $model.preferences.enabled)
            if model.preferences.enabled {
                Picker("Reminder time", selection: $model.preferences.leadTime) {
                    ForEach(RegimenNotificationLeadTime.allCases, id: \.self) { leadTime in
                        Text(leadTime.label).tag(leadTime)
                    }
                }
            }
        } footer: {
            if model.preferences.enabled {
                Text("Reminders follow upcoming doses over the next 90 days. Open fembie regularly to keep them up to date.")
            }
            if let message = model.message { Text(message) }
        }
    }
}
