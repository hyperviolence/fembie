import Foundation

/// One app-owned actor serializes reads and atomic writes to local JSON stores.
actor FileTrackingRepository: TrackingRepository {
    private var regimensCache: [Regimen]?
    private var injectionEventsCache: [InjectionEvent]?
    private var checkInsCache: [CheckIn]?
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private enum Store: String {
        case regimens = "regimens.json"
        case injectionEvents = "injectionEvents.json"
        case checkIns = "checkIns.json"
    }

    // Loading happens on the actor, rather than escaping self during initialization.
    init(baseURL: URL = URL.applicationSupportDirectory.appending(path: "Tracking", directoryHint: .isDirectory)) {
        self.baseURL = baseURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
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

    func save(_ regimen: Regimen) throws {
        try regimen.validate()
        // Refuse to overwrite unreadable data, even if the caller never loaded it.
        _ = try regimens()
        let values = [regimen]
        try persist(values, to: .regimens)
        regimensCache = values
    }

    func save(_ event: InjectionEvent) throws {
        var values = try injectionEvents()
        upsert(&values, item: event)
        try persist(values, to: .injectionEvents)
        injectionEventsCache = values
    }

    func save(_ checkIn: CheckIn) throws {
        guard (0...10).contains(checkIn.mood), (0...10).contains(checkIn.libido),
              (0...10).contains(checkIn.energy) else {
            throw NSError(domain: "FileTrackingRepository", code: 1001,
                          userInfo: [NSLocalizedDescriptionKey: "CheckIn responses must be in the range 0...10."])
        }
        var values = try checkIns()
        upsert(&values, item: checkIn)
        try persist(values, to: .checkIns)
        checkInsCache = values
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
