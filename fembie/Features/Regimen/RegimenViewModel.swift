import Foundation
import Observation

@MainActor
@Observable
final class RegimenViewModel {
    var selectedEster: EstradiolType = .estradiolEnanthate {
        didSet {
            if let route = EsterRoutes.getRoutes(ester: selectedEster).first { selectedRoute = route }
        }
    }
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
    var hasEffectiveUntil = false
    var effectiveUntil: Date
    var showAlert = false
    private(set) var alertMessage = ""
    private(set) var loadError: String?
    private(set) var regimens: [Regimen] = []
    private(set) var editingRegimenID: UUID?
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
        effectiveUntil = now.addingTimeInterval(90 * 86_400)
    }

    var activeRegimens: [Regimen] { regimens.filter { $0.isEffective(at: now) } }
    var savedRegimen: Regimen? {
        editingRegimenID.flatMap { id in regimens.first { $0.id == id } }
            ?? activeRegimens.last ?? regimens.last(where: { $0.effectiveFrom <= now }) ?? regimens.first
    }
    var isEditing: Bool { editingRegimenID != nil }
    var validationMessage: String? {
        do {
            let draft = try makeDraft()
            _ = try schedule.eventCount(for: draft, through: schedule.horizon(for: draft, now: now))
            return nil
        } catch { return error.localizedDescription }
    }
    var canSave: Bool { !isBusy && validationMessage == nil }
    var visibleEvents: [InjectionEvent] {
        let events = regimens.flatMap(\.injectionEvents).sorted { $0.scheduledAt < $1.scheduledAt }
        let past = events.filter { $0.scheduledAt <= now }
        let future = events.filter { $0.scheduledAt > now }
        return Array(past.suffix(pastCount)) + Array(future.prefix(futureCount))
    }
    var hasMorePast: Bool {
        regimens.flatMap(\.injectionEvents).filter { $0.scheduledAt <= now }.count > pastCount
    }
    var hasMoreFuture: Bool {
        regimens.flatMap(\.injectionEvents).filter { $0.scheduledAt > now }.count > futureCount
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
            var loaded: [Regimen] = []
            for saved in try await repository.regimens() {
                let repair = RegimenScheduleRepair.restoringScheduledDates(in: saved)
                let repaired = repair ?? saved
                let extended = try schedule.extending(repaired, through: schedule.horizon(for: repaired, now: now))
                if repair != nil || extended.injectionEvents.count != saved.injectionEvents.count {
                    try await repository.save(extended)
                }
                loaded.append(extended)
            }
            regimens = loaded.sorted { $0.effectiveFrom < $1.effectiveFrom }
            loadError = nil
            hasLoaded = true
        } catch {
            loadError = "Could not load your regimens: \(error.localizedDescription)"
            hasLoaded = false
        }
    }

    func beginAddingRegimen() {
        editingRegimenID = nil
        selectedEster = .estradiolEnanthate
        selectedRoute = .intramuscular
        dose = ""
        interval = ""
        intervalUnit = .days
        firstInjection = now
        hasEffectiveUntil = false
        effectiveUntil = now.addingTimeInterval(90 * 86_400)
    }

    func beginEditing(_ regimen: Regimen) {
        editingRegimenID = regimen.id
        selectedEster = EstradiolType.allCases.first { $0.displayName == regimen.ester } ?? .estradiolEnanthate
        selectedRoute = regimen.route
        dose = regimen.doseMilligramsOfEster.formatted(.number.locale(locale).grouping(.never))
        intervalUnit = .days
        interval = (regimen.intervalHours / 24).formatted(.number.locale(locale).grouping(.never)
            .precision(.significantDigits(1...15)))
        firstInjection = regimen.effectiveFrom
        hasEffectiveUntil = regimen.effectiveUntil != nil
        effectiveUntil = regimen.effectiveUntil ?? regimen.effectiveFrom.addingTimeInterval(90 * 86_400)
    }

    func resetData() async throws {
        guard !isBusy else { throw CocoaError(.fileWriteUnknown) }
        isBusy = true
        defer { isBusy = false }
        try await repository.resetRegimenData()
        regimens = []
        beginAddingRegimen()
        pastCount = 2
        futureCount = 1
        loadError = nil
        hasLoaded = true
    }

    @discardableResult
    func saveRegimen() async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        refreshTime()
        do {
            let wasEditing = isEditing
            let draft = try makeDraft()
            let regimen = try schedule.extending(draft, through: schedule.horizon(for: draft, now: now))
            try await repository.save(regimen)
            if let index = regimens.firstIndex(where: { $0.id == regimen.id }) { regimens[index] = regimen }
            else { regimens.append(regimen) }
            regimens.sort { $0.effectiveFrom < $1.effectiveFrom }
            editingRegimenID = regimen.id
            loadError = nil
            hasLoaded = true
            present(wasEditing ? "Regimen updated successfully." : "Regimen added successfully.")
            return true
        } catch {
            present("Could not save regimen: \(error.localizedDescription)")
            return false
        }
    }

    func setAdjustment(eventID: UUID, to adjustment: InjectionAdjustment) async {
        guard hasLoaded, !isBusy,
              let regimenIndex = regimens.firstIndex(where: { $0.injectionEvents.contains { $0.id == eventID } }),
              let eventIndex = regimens[regimenIndex].injectionEvents.firstIndex(where: { $0.id == eventID }) else { return }
        refreshTime()
        let event = regimens[regimenIndex].injectionEvents[eventIndex]
        let resolved: InjectionAdjustment
        if adjustment == .confirmed {
            if case .moved(let actualAt) = event.adjustment, actualAt <= now { resolved = event.adjustment }
            else if event.scheduledAt > now { resolved = .moved(actualAt: now) }
            else { resolved = .confirmed }
        } else { resolved = adjustment }
        guard event.adjustment != resolved else { return }
        var updated = regimens[regimenIndex]
        updated.injectionEvents[eventIndex].adjustment = resolved
        isBusy = true
        defer { isBusy = false }
        do {
            try await repository.save(updated)
            regimens[regimenIndex] = updated
        } catch { present("Could not save dose change: \(error.localizedDescription). Your previous status is unchanged.") }
    }

    func deleteRegimen(_ regimen: Regimen) async {
        guard !isBusy, regimens.contains(where: { $0.id == regimen.id }) else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await repository.deleteRegimen(id: regimen.id)
            regimens.removeAll { $0.id == regimen.id }
            if editingRegimenID == regimen.id { beginAddingRegimen() }
            present("Regimen deleted.")
        } catch {
            present("Could not delete regimen: \(error.localizedDescription)")
        }
    }

    func showMorePast() { pastCount += 3 }
    func showMoreFuture() async {
        guard !isBusy, let regimen = savedRegimen else { return }
        let available = regimens.flatMap(\.injectionEvents).filter { $0.scheduledAt > now }.count
        if available > futureCount {
            futureCount += 3
            return
        }
        guard let last = regimen.injectionEvents.last,
              regimen.injectionEvents.count < InjectionSchedule.maximumEventCount else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let extraCount = min(3, InjectionSchedule.maximumEventCount - regimen.injectionEvents.count)
            let end = last.scheduledAt.addingTimeInterval(Double(extraCount) * regimen.intervalHours * 3_600)
            let extended = try schedule.extending(regimen, through: end)
            try await repository.save(extended)
            if let index = regimens.firstIndex(where: { $0.id == extended.id }) { regimens[index] = extended }
            futureCount += 3
        } catch { present("Could not extend the schedule: \(error.localizedDescription)") }
    }

    private func makeDraft() throws -> Regimen {
        guard let dose = parseNumber(dose) else { throw RegimenValidationError.invalidDose }
        guard let intervalValue = parseNumber(interval) else { throw RegimenValidationError.invalidInterval }
        let id = editingRegimenID ?? UUID()
        var draft = try Regimen(id: id, ester: selectedEster.displayName, doseMilligramsOfEster: dose,
            route: selectedRoute, intervalHours: intervalValue * Double(intervalUnit.rawValue),
            effectiveFrom: firstInjection, effectiveUntil: hasEffectiveUntil ? effectiveUntil : nil,
            timeZoneIdentifier: TimeZone.current.identifier)
        if let existing = regimens.first(where: { $0.id == id }),
           existing.effectiveFrom == draft.effectiveFrom, existing.intervalHours == draft.intervalHours {
            draft.injectionEvents = existing.injectionEvents.filter { event in
                draft.effectiveUntil.map { event.scheduledAt < $0 } ?? true
            }.map { event in
                var updated = InjectionEvent(id: event.id, regimenID: event.regimenID,
                    scheduledAt: event.scheduledAt, doseMilligramsOfEster: dose)
                updated.adjustment = event.adjustment
                return updated
            }
        }
        return draft
    }

    private func parseNumber(_ input: String) -> Double? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
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
