import SwiftUI

struct LevelsWellbeingMappingControl: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle("Wellbeing data", isOn: $isEnabled)
            .accessibilityHint("Shows mood, libido, and energy on a zero to ten scale")
    }
}
