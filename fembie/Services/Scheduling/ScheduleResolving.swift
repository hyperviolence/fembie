import Foundation
import EstradiolPK

/// App-side boundary: schedule history + overrides -> effective doses.
protocol ScheduleResolving {
    func events(for regimen: Regimen, through end: Date) throws -> [InjectionEvent]
    func doses(from events: [InjectionEvent]) throws -> [DoseAdministration]
}
// TODO: Stable event IDs, elapsed-time intervals, past/future distinction,
// skipped events, moved times, schedule versioning, and undo.
