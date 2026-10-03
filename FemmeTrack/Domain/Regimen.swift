import Foundation


/// Historical regimen versions must remain available when future schedules change.
struct Regimen: Identifiable, Codable {
    let id: UUID
    var ester: String
    var doseMilligramsOfEster: Double
    var intervalHours: Double
    var effectiveFrom: Date
    var effectiveUntil: Date?
    var timeZoneIdentifier: String

    /// Precomputed injection events for this regimen (e.g., one year ahead).
    var injectionEvents: [InjectionEvent] = []

    init(
        id: UUID,
        ester: String,
        doseMilligramsOfEster: Double,
        intervalHours: Double,
        effectiveFrom: Date,
        effectiveUntil: Date?,
        timeZoneIdentifier: String
    ) {
        self.id = id
        self.ester = ester
        self.doseMilligramsOfEster = doseMilligramsOfEster
        self.intervalHours = intervalHours
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.timeZoneIdentifier = timeZoneIdentifier
        self.injectionEvents = []
        // Generate events for one year from the later of 'now' or 'effectiveFrom'
        let base = max(Date(), effectiveFrom)
        let horizon = Calendar.current.date(byAdding: .year, value: 1, to: base) ?? base
        self.generateInjectionEvents(until: horizon)
    }

    /// Regenerate the list of injection events from effectiveFrom up to (and including) endDate,
    /// constrained by effectiveUntil if present.
    mutating func generateInjectionEvents(until endDate: Date) {
        injectionEvents.removeAll()
        guard intervalHours > 0 else { return }
        let horizon = min(effectiveUntil ?? endDate, endDate)
        var current = effectiveFrom
        while current <= horizon {
            injectionEvents.append(InjectionEvent(id: UUID(), regimenID: id,  scheduledAt: current, doseMilligramsOfEster: doseMilligramsOfEster))
            current = current.addingTimeInterval(intervalHours * 3600)
        }
    }

    // v1 supports only estradiol enanthate, subcutaneous.
}
