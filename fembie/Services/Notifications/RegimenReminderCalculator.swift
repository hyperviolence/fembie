import Foundation

nonisolated struct RegimenReminderCalculator {
    func events(regimen: Regimen, leadTime: RegimenNotificationLeadTime,
                now: Date) throws -> [RegimenNotificationEvent] {
        let end = now.addingTimeInterval(90 * 86400)
        let extended = try InjectionSchedule().extending(regimen, through: end)
        return extended.injectionEvents.compactMap { event in
            let injectionAt: Date
            switch event.adjustment {
            case .skipped, .confirmed: return nil
            case .none: injectionAt = event.scheduledAt
            case .moved(let actualAt): injectionAt = actualAt
            }
            guard injectionAt > now, injectionAt <= end else { return nil }
            let timestamp = injectionAt.addingTimeInterval(-Double(leadTime.rawValue))
            guard timestamp > now else { return nil }
            return RegimenNotificationEvent(injectionID: event.id, injectionAt: injectionAt, timestamp: timestamp)
        }.sorted { $0.timestamp < $1.timestamp }
    }
}
