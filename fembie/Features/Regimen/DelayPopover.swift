import SwiftUI

struct DelayPopover: View {
    let event: InjectionEvent
    @Binding var isPresented: Bool
    @Bindable var model: RegimenViewModel
    @State private var delayedUntil: Date = Date()
    var body: some View {
        VStack(spacing: 5) {
            Text("Choose a date:")
                .font(.headline)
            DatePicker(
                        "New date and time",
                        selection: $delayedUntil,
                        displayedComponents: [.date, .hourAndMinute]
                    )
            .datePickerStyle(.wheel)
            .labelsHidden()
            HStack(spacing: 45) {
                Button("Save") {
                    Task {
                        await model.setAdjustment(eventID: event.id, to: .moved(actualAt: delayedUntil))
                    }
                    self.isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                Button("Dismiss") {
                    self.isPresented = false
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .frame(minWidth: 380, minHeight: 320)
        .presentationCompactAdaptation(.popover)
    }
    
}
