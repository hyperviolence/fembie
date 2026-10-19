import SwiftUI

struct LevelsNotificationSection: View {
    @Environment(LevelsNotificationViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section {
            Toggle("Push notifications", isOn: $model.preferences.enabled)
            if model.preferences.enabled {
                Text("Notify me when…")
                    .foregroundStyle(.secondary)
                ForEach(LevelNotificationKind.allCases, id: \.self) { kind in
                    Toggle(kind.label, isOn: Binding(
                        get: { model.preferences.kinds.contains(kind) },
                        set: { selected in
                            if selected { model.preferences.kinds.insert(kind) }
                            else { model.preferences.kinds.remove(kind) }
                        }
                    ))
                }
            }
        } footer: {
            if model.preferences.enabled {
                Text("Alerts follow estimated turning points over the next \(LevelsPredictionHorizon.notifications.futureDays) days, assuming scheduled injections are taken. Highest and lowest refer to the signed rate of change. Open fembie regularly to keep alerts up to date.")
            }
            if let message = model.message {
                Text(message)
            }
        }
    }
}
