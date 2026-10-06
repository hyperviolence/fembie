import SwiftUI

struct CheckInReminderSection: View {
    @Environment(CheckInReminderViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section {
            Toggle("Enable push notifications", isOn: $model.preferences.enabled)
            if model.preferences.enabled {
                DatePicker("Check-in time", selection: $model.time, displayedComponents: .hourAndMinute)
            }
        } footer: {
            if model.preferences.enabled {
                Text("A daily reminder to check in at your selected local time.")
            }
            if let message = model.message {
                Text(message)
            }
        }
    }
}
