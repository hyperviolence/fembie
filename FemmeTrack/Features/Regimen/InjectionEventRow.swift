import SwiftUI

struct InjectionEventRow: View {
    let event: InjectionEvent
    @Bindable var model: RegimenViewModel

    var body: some View {
        let status = InjectionStatus(event: event, now: model.now)
        VStack(alignment: .leading) {
            Text(event.scheduledAt, format: .dateTime.day().month().year().hour().minute())
                .font(.headline)
            Label(status.title, systemImage: status.systemImage)
                .foregroundStyle(.secondary)
            if case .moved(let actualAt) = event.adjustment {
                LabeledContent("Moved to", value: actualAt.formatted(date: .abbreviated, time: .shortened))
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Taken") {
                        Task { await model.setAdjustment(eventID: event.id, to: .confirmed) }
                    }
                        .disabled(event.scheduledAt > model.now || event.adjustment == .confirmed)
                    Button("Skipped") {
                        Task { await model.setAdjustment(eventID: event.id, to: .skipped) }
                    }
                        .disabled(event.adjustment == .skipped)
                    Button("Delayed") { }.disabled(true)
                }
                VStack(alignment: .leading) {
                    Button("Taken") {
                        Task { await model.setAdjustment(eventID: event.id, to: .confirmed) }
                    }
                        .disabled(event.scheduledAt > model.now || event.adjustment == .confirmed)
                    Button("Skipped") {
                        Task { await model.setAdjustment(eventID: event.id, to: .skipped) }
                    }
                        .disabled(event.adjustment == .skipped)
                    Button("Delayed") { }.disabled(true)
                }
            }
            .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Injection \(event.scheduledAt.formatted(date: .abbreviated, time: .shortened)), \(status.title)")
    }
}
