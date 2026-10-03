import Foundation

/// Elapsed-time recurrence, independent of the UI and the current clock.
nonisolated struct InjectionSchedule: Sendable {
    static let maximumEventCount = 10_000

    func eventCount(for regimen: Regimen, through end: Date) throws -> Int {
        try regimen.validate()
        guard end.timeIntervalSinceReferenceDate.isFinite else {
            throw RegimenValidationError.invalidSchedule
        }
        let horizon = min(end, regimen.effectiveUntil ?? end)
        guard horizon >= regimen.effectiveFrom else { return 0 }
        let seconds = regimen.intervalHours * 3600
        guard regimen.effectiveFrom.addingTimeInterval(seconds) > regimen.effectiveFrom else {
            throw RegimenValidationError.invalidInterval
        }
        let quotient = horizon.timeIntervalSince(regimen.effectiveFrom) / seconds
        // Check before converting to Int or allocating an array.
        guard quotient.isFinite, quotient <= Double(Self.maximumEventCount) else {
            throw RegimenValidationError.tooManyEvents
        }
        var count = Int(quotient.rounded(.down)) + 1
        // Date arithmetic can round a quotient just below an integer. Check the
        // actual timestamp at each boundary instead of dropping the last event.
        func includes(_ index: Int) -> Bool {
            let date = regimen.effectiveFrom.addingTimeInterval(Double(index) * seconds)
            return date <= horizon && (regimen.effectiveUntil.map { date < $0 } ?? true)
        }
        if count > 0, !includes(count - 1) { count -= 1 }
        if includes(count) { count += 1 }
        guard count <= Self.maximumEventCount else {
            throw RegimenValidationError.tooManyEvents
        }
        return count
    }

    /// Reuses saved identities and corrections, including when the horizon grows.
    func extending(_ regimen: Regimen, through end: Date) throws -> Regimen {
        let count = try eventCount(for: regimen, through: end)
        let seconds = regimen.intervalHours * 3600
        var existing: [Int: InjectionEvent] = [:]
        for event in regimen.injectionEvents where event.regimenID == regimen.id {
            if let until = regimen.effectiveUntil, event.scheduledAt >= until { continue }
            let position = event.scheduledAt.timeIntervalSince(regimen.effectiveFrom) / seconds
            guard position.isFinite, position >= 0,
                  position < Double(Self.maximumEventCount) else {
                throw RegimenValidationError.invalidSchedule
            }
            let index = Int(position.rounded())
            let expected = regimen.effectiveFrom.addingTimeInterval(Double(index) * seconds)
            // Legacy ISO-8601 files discarded fractions of a second. Match a
            // saved event to its recurrence index instead of recreating its ID.
            guard abs(expected.timeIntervalSince(event.scheduledAt)) < 1,
                  existing[index] == nil else {
                throw RegimenValidationError.invalidSchedule
            }
            existing[index] = event
        }
        var result = regimen
        // Existing events beyond the requested horizon remain available.
        for index in 0..<count {
            let date = regimen.effectiveFrom.addingTimeInterval(Double(index) * seconds)
            if existing[index] == nil {
                let event = InjectionEvent(id: UUID(), regimenID: regimen.id, scheduledAt: date,
                                           doseMilligramsOfEster: regimen.doseMilligramsOfEster)
                existing[index] = event
            }
        }
        guard existing.count <= Self.maximumEventCount else {
            throw RegimenValidationError.tooManyEvents
        }
        result.injectionEvents = existing.values.sorted { $0.scheduledAt < $1.scheduledAt }
        return result
    }

    func horizon(for regimen: Regimen, now: Date) -> Date {
        max(now, regimen.effectiveFrom).addingTimeInterval(366 * 24 * 3600)
    }
}
