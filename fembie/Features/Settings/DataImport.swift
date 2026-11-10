import Foundation

nonisolated enum DataImportError: LocalizedError, Equatable {
    case fileTooLarge
    case invalidJSON
    case unsupportedFormatVersion(Int)
    case unexpectedField(String)
    case tooManyRecords
    case duplicateIdentifier
    case inconsistentInjectionEvent
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "The import file is larger than the 10 MB limit."
        case .invalidJSON: "The file is not a valid fembie JSON export."
        case .unsupportedFormatVersion(let version): "Export format version \(version) is not supported."
        case .unexpectedField(let field): "The file contains an unexpected field: \(field)."
        case .tooManyRecords: "The file contains too many records."
        case .duplicateIdentifier: "The file contains duplicate identifiers."
        case .inconsistentInjectionEvent: "The injection event relationships are inconsistent."
        case .invalidValue: "The file contains an invalid value."
        }
    }
}

nonisolated struct DataImportValidator: Sendable {
    static let maximumFileSize = 10 * 1_024 * 1_024
    static let maximumRecordsPerCollection = 10_000
    private static let rootKeys: Set<String> = [
        "formatVersion", "appVersion", "regimen", "regimens", "injectionEvents", "checkIns"
    ]
    private static let regimenKeys: Set<String> = [
        "id", "ester", "doseMilligramsOfEster", "route", "intervalHours", "effectiveFrom",
        "effectiveUntil", "timeZoneIdentifier", "injectionEvents"
    ]
    private static let eventKeys: Set<String> = [
        "id", "regimenID", "scheduledAt", "doseMilligramsOfEster", "adjustment"
    ]
    private static let checkInKeys: Set<String> = ["id", "recordedAt", "mood", "libido", "energy", "customRatings"]

    func decodeAndValidate(_ data: Data) throws -> DataExport {
        guard data.count <= Self.maximumFileSize else { throw DataImportError.fileTooLarge }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw DataImportError.invalidJSON
        }
        guard let root = object as? [String: Any] else { throw DataImportError.invalidJSON }
        try rejectUnknownKeys(in: root, allowed: Self.rootKeys)
        guard !(root.keys.contains("regimen") && root.keys.contains("regimens")) else {
            throw DataImportError.invalidJSON
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export: DataExport
        do {
            export = try decoder.decode(DataExport.self, from: data)
        } catch {
            throw DataImportError.invalidJSON
        }
        guard export.formatVersion == 1 else {
            throw DataImportError.unsupportedFormatVersion(export.formatVersion)
        }
        guard export.regimens.count <= Self.maximumRecordsPerCollection,
              export.injectionEvents.count <= Self.maximumRecordsPerCollection,
              export.checkIns.count <= Self.maximumRecordsPerCollection else {
            throw DataImportError.tooManyRecords
        }

        try validateObjectArrays(root)
        try validateDomain(export)
        return export
    }

    private func validateObjectArrays(_ root: [String: Any]) throws {
        let regimens: [[String: Any]]
        if let current = root["regimens"] as? [[String: Any]] {
            regimens = current
        } else if let legacy = root["regimen"] as? [String: Any] {
            regimens = [legacy]
        } else if root["regimen"] is NSNull {
            regimens = []
        } else {
            throw DataImportError.invalidJSON
        }
        guard let events = root["injectionEvents"] as? [[String: Any]],
              let checkIns = root["checkIns"] as? [[String: Any]] else {
            throw DataImportError.invalidJSON
        }
        for regimen in regimens {
            try rejectUnknownKeys(in: regimen, allowed: Self.regimenKeys)
            guard let nested = regimen["injectionEvents"] as? [[String: Any]] else {
                throw DataImportError.invalidJSON
            }
            for event in nested { try validateEventObject(event) }
        }
        for event in events { try validateEventObject(event) }
        for checkIn in checkIns {
            try rejectUnknownKeys(in: checkIn, allowed: Self.checkInKeys)
            if let ratings = checkIn["customRatings"] as? [[String: Any]] {
                for rating in ratings {
                    try rejectUnknownKeys(in: rating, allowed: ["id", "label", "lowLabel", "highLabel", "value"])
                }
            }
        }
    }

    private func validateEventObject(_ event: [String: Any]) throws {
        try rejectUnknownKeys(in: event, allowed: Self.eventKeys)
        guard let adjustment = event["adjustment"] as? [String: Any],
              adjustment.count == 1,
              let kind = adjustment.keys.first,
              ["none", "confirmed", "skipped", "moved"].contains(kind),
              let payload = adjustment[kind] as? [String: Any] else {
            throw DataImportError.invalidJSON
        }
        let allowedPayloadKeys: Set<String> = kind == "moved" ? ["actualAt"] : []
        try rejectUnknownKeys(in: payload, allowed: allowedPayloadKeys)
    }

    private func validateDomain(_ export: DataExport) throws {
        guard unique(export.regimens.map(\.id)),
              unique(export.injectionEvents.map(\.id)),
              unique(export.checkIns.map(\.id)) else {
            throw DataImportError.duplicateIdentifier
        }
        do {
            for regimen in export.regimens { try regimen.validate() }
            for event in export.injectionEvents { try event.validate() }
            for checkIn in export.checkIns { try checkIn.validate() }
        } catch {
            throw DataImportError.invalidValue
        }

        let regimenIDs = Set(export.regimens.map(\.id))
        guard export.injectionEvents.allSatisfy({ regimenIDs.contains($0.regimenID) }) else {
            throw DataImportError.inconsistentInjectionEvent
        }
        let nestedEvents = export.regimens.flatMap(\.injectionEvents)
        let topLevelEvents = Dictionary(uniqueKeysWithValues: export.injectionEvents.map { ($0.id, $0) })
        guard unique(nestedEvents.map(\.id)),
              nestedEvents.allSatisfy({ nested in
                  guard let topLevel = topLevelEvents[nested.id] else {
                      // Version 1 exports may store scheduled events only inside the regimen.
                      return true
                  }
                  return nested.regimenID == topLevel.regimenID &&
                      nested.scheduledAt == topLevel.scheduledAt &&
                      nested.doseMilligramsOfEster == topLevel.doseMilligramsOfEster &&
                      nested.adjustment == topLevel.adjustment
              }) else {
            throw DataImportError.inconsistentInjectionEvent
        }
    }

    private func rejectUnknownKeys(in object: [String: Any], allowed: Set<String>) throws {
        if let key = object.keys.first(where: { !allowed.contains($0) }) {
            throw DataImportError.unexpectedField(key)
        }
    }

    private func unique<T: Hashable>(_ values: [T]) -> Bool {
        Set(values).count == values.count
    }
}

nonisolated struct DataImporter: Sendable {
    private let repository: any TrackingRepository
    private let validator = DataImportValidator()

    init(repository: any TrackingRepository) {
        self.repository = repository
    }

    func importData(_ data: Data) async throws {
        let export = try validator.decodeAndValidate(data)
        try await repository.replaceTrackingData(
            regimens: export.regimens,
            injectionEvents: export.injectionEvents,
            checkIns: export.checkIns
        )
    }
}
