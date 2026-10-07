import Foundation
import Observation

@MainActor
@Observable
final class RegimenViewModel {
    var selectedEster: EstradiolType = .estradiolEnanthate
    var selectedRoute: EstradiolRoute = .intramuscular
    var dose = ""
    var interval = ""
    var intervalUnit: RegimenIntervalUnit = .days {
        didSet {
            guard intervalUnit != oldValue, let value = parseNumber(interval) else { return }
            let converted = value * Double(oldValue.rawValue) / Double(intervalUnit.rawValue)
            guard converted.isFinite else { return }
            interval = converted.formatted(.number.locale(locale).grouping(.never)
                .precision(.significantDigits(1...15)))
        }
    }
    var firstInjection: Date
    var showAlert = false
    private(set) var alertMessage = ""
    private(set) var loadError: String?
    private(set) var savedRegimen: Regimen?
    private(set) var isBusy = false
    private(set) var hasLoaded = false
    private(set) var now: Date
    private(set) var pastCount = 2
    private(set) var futureCount = 1

    @ObservationIgnored private let repository: any TrackingRepository
    @ObservationIgnored private let clock: @MainActor () -> Date
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let schedule = InjectionSchedule()

    init(repository: any TrackingRepository, locale: Locale = .current,
         clock: @escaping @MainActor () -> Date = { Date() }) {
        self.repository = repository
        self.locale = locale
        self.clock = clock
        let now = clock()
        self.now = now
        firstInjection = now
    }

    var validationMessage: String? {
        do {
            let draft = try makeDraft()
            let endDate = schedule.horizon(for: draft, now: now)

            // Check schedule validity; the count itself isn't needed here.
            _ = try schedule.eventCount(for: draft, through: endDate)
            return nil
        } catch { return error.localizedDescription }
    }

    var canSave: Bool { !isBusy }
    var visibleEvents: [InjectionEvent] {
        guard let savedRegimen else { return [] }
        let past = savedRegimen.injectionEvents.filter { $0.scheduledAt <= now }
        let future = savedRegimen.injectionEvents.filter { $0.scheduledAt > now }
        return Array(past.suffix(pastCount)) + Array(future.prefix(futureCount))
    }
    var hasMorePast: Bool {
        (savedRegimen?.injectionEvents.filter { $0.scheduledAt <= now }.count ?? 0) > pastCount
    }
    var hasMoreFuture: Bool {
        guard let regimen = savedRegimen else { return false }
        let future = regimen.injectionEvents.filter { $0.scheduledAt > now }
        if future.count > futureCount { return true }
        guard regimen.injectionEvents.count < InjectionSchedule.maximumEventCount,
              let last = regimen.injectionEvents.last else { return false }
        let intervalSeconds = regimen.intervalHours * 3600
        let nextInjection = last.scheduledAt.addingTimeInterval(intervalSeconds)
        if let until = regimen.effectiveUntil {
            return nextInjection < until
        }
        return true
    }
    var regimenTitle: String {
        guard let savedRegimen else { return "Saved regimen" }
        if savedRegimen.effectiveFrom > now { return "Upcoming regimen" }
        if let until = savedRegimen.effectiveUntil, until <= now { return "Ended regimen" }
        return "Current regimen"
    }

    func refreshTime() { now = clock() }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        refreshTime()
        do {
            if let saved = try await repository.regimens().first {
                let repaired = RegimenScheduleRepair.restoringScheduledDates(in: saved)
                let input = repaired ?? saved
                let extended = try schedule.extending(input, through: schedule.horizon(for: input, now: now))
                if repaired != nil || extended.injectionEvents.count != saved.injectionEvents.count {
                    try await repository.save(extended)
                }
                savedRegimen = extended
            } else {
                savedRegimen = nil
            }
            loadError = nil
            hasLoaded = true
        } catch {
            loadError = "Could not load your regimen: \(error.localizedDescription)"
            // Preserve displayed data; the form can still save a replacement.
            hasLoaded = false
        }
    }

    func resetData() async throws {
        guard !isBusy else {
            throw NSError(domain: "RegimenViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Your regimen is still being updated. Please try again."])
        }
        isBusy = true
        defer { isBusy = false }
        try await repository.resetRegimenData()
        savedRegimen = nil
        selectedEster = .estradiolEnanthate
        selectedRoute = .intramuscular
        dose = ""
        interval = ""
        intervalUnit = .days
        refreshTime()
        firstInjection = now
        pastCount = 2
        futureCount = 1
        loadError = nil
        hasLoaded = true
        showAlert = false
        alertMessage = ""
    }

    func saveRegimen() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        refreshTime()
        do {
            let draft = try makeDraft()
            let regimen = try schedule.extending(draft, through: schedule.horizon(for: draft, now: now))
            try await repository.save(regimen)
            savedRegimen = regimen
            loadError = nil
            hasLoaded = true
            pastCount = 2
            futureCount = 1
            present("Regimen saved successfully.")
        } catch {
            present("Could not save regimen: \(error.localizedDescription)")
        }
    }

    func setAdjustment(eventID: UUID, to adjustment: InjectionAdjustment) async {
        guard hasLoaded, !isBusy, var regimen = savedRegimen,
              let index = regimen.injectionEvents.firstIndex(where: { $0.id == eventID }) else { return }
        refreshTime()
        let event = regimen.injectionEvents[index]
        let effectiveTime: Date = if case .moved(let actualAt) = event.adjustment {
            actualAt
        } else {
            event.scheduledAt
        }
        let resolved: InjectionAdjustment
        if adjustment == .confirmed {
            if case .moved(let actualAt) = event.adjustment, actualAt <= now {
                resolved = event.adjustment
            } else if effectiveTime > now {
                resolved = .moved(actualAt: now)
            } else {
                resolved = .confirmed
            }
        } else {
            resolved = adjustment
        }
        guard event.adjustment != resolved else { return }
        isBusy = true
        defer { isBusy = false }
        // Keep the recurrence date immutable; prediction reads the actual time from .moved.
        regimen.injectionEvents[index].adjustment = resolved
        do {
            try await repository.save(regimen)
            savedRegimen = regimen
        } catch {
            present("Could not save injection change: \(error.localizedDescription). Your previous status is unchanged.")
        }
    }

    func showMorePast() { pastCount += 3 }

    func showMoreFuture() async {
        guard hasLoaded, !isBusy, let regimen = savedRegimen else { return }
        let available = regimen.injectionEvents.filter { $0.scheduledAt > now }.count
        if available > futureCount || !hasMoreFuture {
            futureCount += 3
            return
        }
        guard let last = regimen.injectionEvents.last else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let remainingCapacity = InjectionSchedule.maximumEventCount - regimen.injectionEvents.count
            let extraCount = min(3, remainingCapacity)
            let intervalSeconds = regimen.intervalHours * 3600
            let elapsedSeconds = last.scheduledAt.timeIntervalSince(regimen.effectiveFrom)
            let lastIndex = (elapsedSeconds / intervalSeconds).rounded()
            let nextIndex = lastIndex + Double(extraCount)
            let hoursFromFirstInjection = nextIndex * regimen.intervalHours
            let secondsFromFirstInjection = hoursFromFirstInjection * 3600
            let endDate = regimen.effectiveFrom.addingTimeInterval(secondsFromFirstInjection)
            let extended = try schedule.extending(regimen, through: endDate)
            try await repository.save(extended)
            savedRegimen = extended
            futureCount += 3
        } catch { present("Could not extend the schedule: \(error.localizedDescription)") }
    }

    private func makeDraft() throws -> Regimen {
        guard let dose = parseNumber(dose) else {
            throw RegimenValidationError.invalidDose
        }
        guard let intervalValue = parseNumber(interval) else {
            throw RegimenValidationError.invalidInterval
        }
        return try Regimen(id: UUID(), ester: selectedEster.displayName, doseMilligramsOfEster: dose, route: selectedRoute, 
                           intervalHours: intervalValue * Double(intervalUnit.rawValue), effectiveFrom: firstInjection,
                           effectiveUntil: nil, timeZoneIdentifier: TimeZone.current.identifier)
    }

    private func parseNumber(_ input: String) -> Double? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        // Require the entire input to be a decimal number; reject grouping and trailing text.
        let parts = text.components(separatedBy: separator)
        guard parts.count <= 2, parts.contains(where: { !$0.isEmpty }),
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        let strategy = FloatingPointParseStrategy(format: FloatingPointFormatStyle<Double>.number.locale(locale), lenient: false)
        return try? strategy.parse(text)
    }

    private func present(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
