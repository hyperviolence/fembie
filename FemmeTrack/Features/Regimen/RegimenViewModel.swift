import Foundation
import Observation

@MainActor
@Observable
final class RegimenViewModel {
    var selectedEster: EstradiolType = .estradiolEnanthate
    var selectedRoute: EstradiolRoute = .subcutaneous
    var dose = ""
    var intervalDays = ""
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

    var canSave: Bool { hasLoaded && !isBusy && validationMessage == nil }
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
            // Legacy stores can contain several versions. Display the latest one,
            // including a future version; the next save replaces the entire array.
            if let saved = try await repository.regimens().max(by: { $0.effectiveFrom < $1.effectiveFrom }) {
                let extended = try schedule.extending(saved, through: schedule.horizon(for: saved, now: now))
                if extended.injectionEvents.count != saved.injectionEvents.count {
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
            // Preserve the last successfully displayed data and block writes until retry.
            hasLoaded = false
        }
    }

    func saveRegimen() async {
        guard hasLoaded, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        refreshTime()
        do {
            let draft = try makeDraft()
            let regimen = try schedule.extending(draft, through: schedule.horizon(for: draft, now: now))
            try await repository.save(regimen)
            savedRegimen = regimen
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
        // A future projection cannot be confirmed as already taken.
        if adjustment == .confirmed, regimen.injectionEvents[index].scheduledAt > now { return }
        guard regimen.injectionEvents[index].adjustment != adjustment else { return }
        isBusy = true
        defer { isBusy = false }
        regimen.injectionEvents[index].adjustment = adjustment
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
        guard let days = parseNumber(intervalDays) else {
            throw RegimenValidationError.invalidInterval
        }
        return try Regimen(id: UUID(), ester: selectedEster.displayName, doseMilligramsOfEster: dose,
                           intervalHours: days * 24, effectiveFrom: firstInjection,
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
