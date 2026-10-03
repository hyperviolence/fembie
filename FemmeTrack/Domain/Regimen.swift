import Foundation

/// The saved regimen is replaced in full when the user saves a new one.
nonisolated struct Regimen: Identifiable, Codable, Sendable {
    let id: UUID
    var ester: String
    var doseMilligramsOfEster: Double
    var intervalHours: Double
    var effectiveFrom: Date
    var effectiveUntil: Date?
    var timeZoneIdentifier: String
    var injectionEvents: [InjectionEvent] = []

    init(id: UUID, ester: String, doseMilligramsOfEster: Double, intervalHours: Double,
         effectiveFrom: Date, effectiveUntil: Date?, timeZoneIdentifier: String) throws {
        self.id = id
        self.ester = ester
        self.doseMilligramsOfEster = doseMilligramsOfEster
        self.intervalHours = intervalHours
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.timeZoneIdentifier = timeZoneIdentifier
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
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw RegimenValidationError.invalidSchedule
        }
    }
}
