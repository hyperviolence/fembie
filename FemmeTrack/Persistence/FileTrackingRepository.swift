import Foundation

/// A simple JSON file–backed implementation of `TrackingRepository`.
/// Stores each entity type as a separate JSON file under Application Support.
/// Thread-safe via actor isolation. Writes occur immediately on each save.
actor FileTrackingRepository: TrackingRepository {
    // MARK: - In-memory caches
    private var regimensCache: [Regimen] = []
    private var injectionEventsCache: [InjectionEvent] = []
    private var checkInsCache: [CheckIn] = []

    // MARK: - File locations and codecs
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Filenames
    private enum Store: String {
        case regimens = "regimens.json"
        case injectionEvents = "injectionEvents.json"
        case checkIns = "checkIns.json"
    }

    // MARK: - Initialization
    init() throws {
        // Resolve Application Support/Tracking directory
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("Tracking", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.baseURL = dir

        // Configure encoders/decoders
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        // Initial load (non-throwing defaults to empty if files missing)
        self.regimensCache = (try? load([Regimen].self, from: .regimens)) ?? []
        self.injectionEventsCache = (try? load([InjectionEvent].self, from: .injectionEvents)) ?? []
        self.checkInsCache = (try? load([CheckIn].self, from: .checkIns)) ?? []
    }

    // MARK: - TrackingRepository
    func regimens() throws -> [Regimen] { regimensCache }
    func injectionEvents() throws -> [InjectionEvent] { injectionEventsCache }
    func checkIns() throws -> [CheckIn] { checkInsCache }

    func save(_ regimen: Regimen) throws {
        upsert(&regimensCache, item: regimen) { $0.id == $1.id }
        try persist(regimensCache, to: .regimens)
    }

    func save(_ event: InjectionEvent) throws {
        upsert(&injectionEventsCache, item: event) { $0.id == $1.id }
        try persist(injectionEventsCache, to: .injectionEvents)
    }

    func save(_ checkIn: CheckIn) throws {
        // Validate ranges 0...10 before persisting
        guard (0...10).contains(checkIn.mood),
              (0...10).contains(checkIn.libido),
              (0...10).contains(checkIn.energy) else {
            throw NSError(domain: "FileTrackingRepository", code: 1001, userInfo: [NSLocalizedDescriptionKey: "CheckIn responses must be in the range 0...10."])
        }
        upsert(&checkInsCache, item: checkIn) { $0.id == $1.id }
        try persist(checkInsCache, to: .checkIns)
    }

    // MARK: - Helpers
    private func url(for store: Store) -> URL {
        baseURL.appendingPathComponent(store.rawValue)
    }

    private func load<T: Decodable>(_ type: T.Type, from store: Store) throws -> T {
        let url = url(for: store)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // For arrays, return empty if missing
            if T.self is [Regimen].Type || T.self is [InjectionEvent].Type || T.self is [CheckIn].Type {
                return [] as! T
            }
            throw NSError(domain: "FileTrackingRepository", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Missing store file: \(store.rawValue)"])
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func persist<T: Encodable>(_ value: T, to store: Store) throws {
        let url = url(for: store)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func upsert<T>(_ array: inout [T], item: T, equals: (T, T) -> Bool) {
        if let idx = array.firstIndex(where: { equals($0, item) }) {
            array[idx] = item
        } else {
            array.append(item)
        }
    }
}
