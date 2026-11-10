import Foundation

/// One independently scheduled treatment that can overlap other regimens.
nonisolated struct Regimen: Identifiable, Codable, Sendable {
    let id: UUID
    var ester: String
    var doseMilligramsOfEster: Double
    var route: EstradiolRoute
    var intervalHours: Double
    var effectiveFrom: Date
    var effectiveUntil: Date?
    var timeZoneIdentifier: String
    var injectionEvents: [InjectionEvent] = []
    var color: RegimenColor?

    init(id: UUID, ester: String, doseMilligramsOfEster: Double, route: EstradiolRoute, intervalHours: Double,
         effectiveFrom: Date, effectiveUntil: Date?, timeZoneIdentifier: String, color: RegimenColor? = nil) throws {
        self.id = id
        self.ester = ester
        self.route = route
        self.doseMilligramsOfEster = doseMilligramsOfEster
        self.intervalHours = intervalHours
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.timeZoneIdentifier = timeZoneIdentifier
        self.color = color
        try validate()
    }

    func validate() throws {
        guard doseMilligramsOfEster.isFinite, doseMilligramsOfEster > 0 else {
            throw RegimenValidationError.invalidDose
        }
        guard intervalHours.isFinite, intervalHours > 0,
              (intervalHours * 3600).isFinite else {
            throw RegimenValidationError.invalidInterval
        }
        guard effectiveFrom.timeIntervalSinceReferenceDate.isFinite else {
            throw RegimenValidationError.invalidSchedule
        }
        if let until = effectiveUntil {
            guard until.timeIntervalSinceReferenceDate.isFinite, until > effectiveFrom else {
                throw RegimenValidationError.invalidSchedule
            }
        }
        guard TimeZone(identifier: timeZoneIdentifier) != nil,
              Set(injectionEvents.map(\.id)).count == injectionEvents.count else {
            throw RegimenValidationError.invalidSchedule
        }
        for event in injectionEvents {
            try event.validate(for: id)
        }
    }

    func isEffective(at date: Date) -> Bool {
        effectiveFrom <= date && (effectiveUntil.map { date < $0 } ?? true)
    }
}
