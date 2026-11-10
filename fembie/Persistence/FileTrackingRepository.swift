import Foundation

/// One app-owned actor serializes reads and atomic writes to local JSON stores.
actor FileTrackingRepository: TrackingRepository {
    private var regimensCache: [Regimen]?
    private var injectionEventsCache: [InjectionEvent]?
    private var checkInsCache: [CheckIn]?
    private var labResultsCache: [LabResult]?
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private enum Store: String {
        case regimens = "regimens.json"
        case injectionEvents = "injectionEvents.json"
        case checkIns = "checkIns.json"
        case labResults = "labResults.json"
    }

    // Loading happens on the actor, rather than escaping self during initialization.
    init(baseURL: URL = URL.applicationSupportDirectory.appending(path: "Tracking", directoryHint: .isDirectory)) {
        self.baseURL = baseURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    func regimens() throws -> [Regimen] {
        if let regimensCache { return regimensCache }
        let values: [Regimen] = try load(from: .regimens)
        for value in values { try value.validate() }
        regimensCache = values
        return values
    }

    func injectionEvents() throws -> [InjectionEvent] {
        if let injectionEventsCache { return injectionEventsCache }
        let values: [InjectionEvent] = try load(from: .injectionEvents)
        injectionEventsCache = values
        return values
    }

    func checkIns() throws -> [CheckIn] {
        if let checkInsCache { return checkInsCache }
        let values: [CheckIn] = try load(from: .checkIns)
        checkInsCache = values
        return values
    }

    func labResults() throws -> [LabResult] {
        if let labResultsCache { return labResultsCache }
        let values: [LabResult] = try load(from: .labResults)
        labResultsCache = values
        return values
    }

    func resetRegimenData() throws {
        // A reset must also recover stores whose JSON can no longer be decoded.
        let previousEvents = try? injectionEvents()
        let previousRegimens = try? regimens()
        do {
            try persist([InjectionEvent](), to: .injectionEvents)
            try persist([Regimen](), to: .regimens)
        } catch {
            // A reset spans two files. Restore either file that was already changed
            // so callers never observe an intentionally half-cleared repository.
            if let previousEvents { try? persist(previousEvents, to: .injectionEvents) }
            if let previousRegimens { try? persist(previousRegimens, to: .regimens) }
            throw error
        }
        injectionEventsCache = []
        regimensCache = []
    }

    func resetWellbeingData() throws {
        try persist([CheckIn](), to: .checkIns)
        checkInsCache = []
    }

    func save(_ result: LabResult) throws {
        try result.validate()
        var values = try labResults()
        upsert(&values, item: result)
        try persist(values, to: .labResults)
        labResultsCache = values
    }

    func deleteLabResult(id: UUID) throws {
        var values = try labResults()
        guard values.contains(where: { $0.id == id }) else { return }
        values.removeAll { $0.id == id }
        try persist(values, to: .labResults)
        labResultsCache = values
    }

    func save(_ regimen: Regimen) throws {
        try regimen.validate()
        // A valid save can also recover a store whose previous JSON is corrupt.
        var values = (try? regimens()) ?? []
        upsert(&values, item: regimen)
        values.sort { $0.effectiveFrom < $1.effectiveFrom }
        try persist(values, to: .regimens)
        regimensCache = values
    }

    func deleteRegimen(id: UUID) throws {
        var savedRegimens = try regimens()
        guard savedRegimens.contains(where: { $0.id == id }) else { return }
        let previousRegimens = savedRegimens
        let previousEvents = try injectionEvents()
        savedRegimens.removeAll { $0.id == id }
        let remainingEvents = previousEvents.filter { $0.regimenID != id }
        do {
            try persist(savedRegimens, to: .regimens)
            try persist(remainingEvents, to: .injectionEvents)
        } catch {
            try? persist(previousRegimens, to: .regimens)
            try? persist(previousEvents, to: .injectionEvents)
            throw error
        }
        regimensCache = savedRegimens
        injectionEventsCache = remainingEvents
    }

    func save(_ event: InjectionEvent) throws {
        try event.validate()
        var values = try injectionEvents()
        upsert(&values, item: event)
        try persist(values, to: .injectionEvents)
        injectionEventsCache = values
    }

    func deleteCustomMetric(id: UUID) throws {
        var values = try checkIns()
        for index in values.indices {
            values[index].customRatings.removeAll { $0.id == id }
        }
        // Commit the entire change atomically before updating the in-memory cache.
        try persist(values, to: .checkIns)
        checkInsCache = values
    }

    func save(_ checkIn: CheckIn) throws {
        try checkIn.validate()
        var values = try checkIns()
        upsert(&values, item: checkIn)
        try persist(values, to: .checkIns)
        checkInsCache = values
    }

    func replaceTrackingData(regimens: [Regimen], injectionEvents: [InjectionEvent], checkIns: [CheckIn]) throws {
        let previousRegimens = try self.regimens()
        let previousEvents = try self.injectionEvents()
        let previousCheckIns = try self.checkIns()
        do {
            try persist(regimens, to: .regimens)
            try persist(injectionEvents, to: .injectionEvents)
            try persist(checkIns, to: .checkIns)
        } catch {
            try? persist(previousRegimens, to: .regimens)
            try? persist(previousEvents, to: .injectionEvents)
            try? persist(previousCheckIns, to: .checkIns)
            throw error
        }
        regimensCache = regimens
        injectionEventsCache = injectionEvents
        checkInsCache = checkIns
    }

    func syncSnapshot() throws -> SyncSnapshot {
        var snapshot = SyncSnapshot()
        for value in try regimens() { try snapshot.insert(value, key: "regimen/\(value.id)") }
        for value in try injectionEvents() { try snapshot.insert(value, key: "event/\(value.id)") }
        for value in try checkIns() { try snapshot.insert(value, key: "checkIn/\(value.id)") }
        for value in try labResults() { try snapshot.insert(value, key: "lab/\(value.id)") }
        return snapshot
    }

    /// Rebase edits made during network requests before replacing local data.
    func applySyncSnapshot(_ remote: SyncSnapshot, captured: SyncSnapshot) throws -> Bool {
        try remote.validate()
        let current = try syncSnapshot()
        let merged = try SyncSnapshot.merge(local: remote, remote: current, baseline: captured)
        let regimens = try merged.values(Regimen.self, prefix: "regimen/")
        let events = try merged.values(InjectionEvent.self, prefix: "event/")
        let checkIns = try merged.values(CheckIn.self, prefix: "checkIn/")
        let labs = try merged.values(LabResult.self, prefix: "lab/")
        for value in regimens { try value.validate() }
        for value in events { try value.validate() }
        for value in checkIns { try value.validate() }
        for value in labs { try value.validate() }
        let oldLabs = try labResults()
        do {
            try persist(labs, to: .labResults)
            try replaceTrackingData(regimens: regimens, injectionEvents: events, checkIns: checkIns)
        } catch {
            try? persist(oldLabs, to: .labResults)
            throw error
        }
        labResultsCache = labs
        return current.records != merged.records.filter { !$0.key.hasPrefix("preference/") }
    }

    private func load<Element: Decodable>(from store: Store) throws -> [Element] {
        let data: Data
        do {
            data = try Data(contentsOf: baseURL.appending(path: store.rawValue))
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
        return try decoder.decode([Element].self, from: data)
    }

    private func persist<T: Encodable>(_ value: T, to store: Store) throws {
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try data.write(to: baseURL.appending(path: store.rawValue), options: .atomic)
    }

    private func upsert<T: Identifiable>(_ array: inout [T], item: T) {
        if let index = array.firstIndex(where: { $0.id == item.id }) {
            array[index] = item
        } else {
            array.append(item)
        }
    }
}
