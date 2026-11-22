import SwiftUI

struct InjectionEventRow: View {
    @Bindable var model: RegimenViewModel
    @State private var showingDelayPicker = false
    let event: InjectionEvent
    @State private var delayedUntil = Date()

    var body: some View {
        let status = InjectionStatus(event: event, now: model.now)
        let regimenColor = model.regimens.first(where: { $0.id == event.regimenID })?.color
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                if let regimenColor {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(regimenColor.color)
                        .accessibilityLabel(Text(regimenColor.label))
                }
                Text(event.scheduledAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.headline)
                    .foregroundStyle(regimenColor?.color ?? .primary)
            }
            if event.isIndividual {
                if let treatment = model.regimens.first(where: { $0.id == event.regimenID }) {
                    Text("\(treatment.ester) · \(treatment.route.displayName)")
                        .font(.caption)
                }
                Text("Individual dose · \(event.doseMilligramsOfEster, format: .number) mg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Label(status.title, systemImage: status.systemImage)
                .foregroundColor(status.color)
            if case .moved(let actualAt) = event.adjustment {
                LabeledContent("Moved to", value: actualAt.formatted(date: .abbreviated, time: .shortened))
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Taken") {
                        Task { await model.setAdjustment(eventID: event.id, to: .confirmed) }
                    }
                        .disabled(status == .confirmed)
                    Button("Skipped") {
                        Task { await model.setAdjustment(eventID: event.id, to: .skipped) }
                    }
                        .disabled(event.adjustment == .skipped)
                    Button("Delayed") {
                        showingDelayPicker = true
                    }
                    .popover(isPresented: $showingDelayPicker) {
                        DelayPopover(event: event, isPresented: $showingDelayPicker, model: model)
                    }
                }
                
                VStack(alignment: .leading) {
                    Button("Taken") {
                        Task { await model.setAdjustment(eventID: event.id, to: .confirmed) }
                    }
                        .disabled(status == .confirmed)
                    Button("Skipped") {
                        Task { await model.setAdjustment(eventID: event.id, to: .skipped) }
                    }
                        .disabled(event.adjustment == .skipped)
                    Button("Delayed") {
                        showingDelayPicker = true
                    }
                    .popover(isPresented: $showingDelayPicker) {
                        DelayPopover(event: event, isPresented: $showingDelayPicker, model: model)
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dose \(event.scheduledAt.formatted(date: .abbreviated, time: .shortened)), \(status.title)")
    }
}
