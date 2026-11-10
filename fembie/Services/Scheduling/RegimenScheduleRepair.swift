import Foundation

/// Repairs the earlier edit that replaced recurrence dates with confirmed actual times.
nonisolated enum RegimenScheduleRepair {
    static func restoringScheduledDates(in regimen: Regimen) -> Regimen? {
        guard !regimen.injectionEvents.contains(where: \.isIndividual),
              (try? regimen.validate()) != nil,
              regimen.injectionEvents.count <= InjectionSchedule.maximumEventCount,
              Set(regimen.injectionEvents.map(\.id)).count == regimen.injectionEvents.count else { return nil }
        var result = regimen
        var changed = false
        // The affected version kept the complete original array in recurrence order.
        // Only repair when every unaffected entry still matches its original index.
        for (index, event) in regimen.injectionEvents.enumerated() {
            guard event.regimenID == regimen.id else { return nil }
            let expected = regimen.effectiveFrom.addingTimeInterval(Double(index) * (regimen.intervalHours * 3600))
            guard expected.timeIntervalSinceReferenceDate.isFinite,
                  regimen.effectiveUntil.map({ expected < $0 }) ?? true else { return nil }
            if event.scheduledAt == expected { continue }
            guard event.adjustment == .confirmed,
                  event.scheduledAt.timeIntervalSinceReferenceDate.isFinite else { return nil }
            result.injectionEvents[index] = InjectionEvent(id: event.id, regimenID: event.regimenID,
                scheduledAt: expected, doseMilligramsOfEster: event.doseMilligramsOfEster,
                adjustment: .moved(actualAt: event.scheduledAt))
            changed = true
        }
        return changed ? result : nil
    }
}
