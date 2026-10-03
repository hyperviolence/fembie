import SwiftUI

struct CheckInView: View {
    @State private var mood = 5.0
    @State private var libido = 5.0
    @State private var energy = 5.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Interface preview only. Ratings are not saved yet.")
                        .foregroundStyle(.secondary)
                }
                Section("How do you feel?") {
                    rating("Mood", value: $mood, low: "Very low", high: "Very good")
                    rating("Libido", value: $libido, low: "No desire", high: "Very strong")
                    rating("Energy", value: $energy, low: "Exhausted", high: "Very energetic")
                }
                Section {
                    Button("Save check-in") { }
                        .disabled(true)
                }
                Section("Reminders") {
                    Text("Optional local notifications will be configured here.")
                }
                Section("Depressive symptom tracking") {
                    Text("Optional MADRS-S support is planned for a later release.")
                }
            }
            .navigationTitle("Wellbeing")
        }
    }

    private func rating(_ title: String, value: Binding<Double>, low: String, high: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Slider(value: value, in: 0...10, step: 1)
                .accessibilityLabel(title)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
