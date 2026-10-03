import SwiftUI

struct InjectionEventRow: View {
    let event: InjectionEvent
    let now: Date
    let setAdjustment: (InjectionAdjustment) -> Void

    var body: some View {
        let status = InjectionStatus(event: event, now: now)
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
                    Button("Taken") { setAdjustment(.confirmed) }
                        .disabled(event.scheduledAt > now || event.adjustment == .confirmed)
                    Button("Skipped") { setAdjustment(.skipped) }
                        .disabled(event.adjustment == .skipped)
                    Button("Delayed") { }.disabled(true)
                }
                VStack(alignment: .leading) {
                    Button("Taken") { setAdjustment(.confirmed) }
                        .disabled(event.scheduledAt > now || event.adjustment == .confirmed)
                    Button("Skipped") { setAdjustment(.skipped) }
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
