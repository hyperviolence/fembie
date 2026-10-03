import SwiftUI

struct InjectionEventsSection: View {
    let model: RegimenViewModel

    var body: some View {
        Section("Injection events") {
            if model.hasMorePast {
                Button("Show more past injections…", action: model.showMorePast)
            }
            ForEach(model.visibleEvents) { event in
                InjectionEventRow(event: event, now: model.now) { adjustment in
                    Task { await model.setAdjustment(eventID: event.id, to: adjustment) }
                }
            }
            if model.visibleEvents.isEmpty {
                ContentUnavailableView("No scheduled injections", systemImage: "calendar",
                                       description: Text("Save a regimen to generate your injection schedule."))
            }
            if model.hasMoreFuture {
                Button("Show more future injections…") { Task { await model.showMoreFuture() } }
            }
        }
        .disabled(model.isBusy || !model.hasLoaded)
    }
}
