import Foundation

/// A versioned, record-level snapshot. Missing keys represent deletions relative to a baseline.
nonisolated struct SyncSnapshot: Codable, Equatable, Sendable {
    var version = 1
    var records: [String: Data] = [:]

    mutating func insert<T: Encodable>(_ value: T, key: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        records[key] = try encoder.encode(value)
    }

    func values<T: Decodable>(_ type: T.Type, prefix: String) throws -> [T] {
        try records.keys.sorted().filter { $0.hasPrefix(prefix) }.map {
            try JSONDecoder().decode(type, from: records[$0] ?? Data())
        }
    }

    func validate() throws {
        guard version == 1 else { throw SyncError.unsupportedVersion }
        let decoder = JSONDecoder()
        for (key, data) in records {
            switch key.split(separator: "/").first {
            case "regimen":
                let value = try decoder.decode(Regimen.self, from: data)
                guard key == "regimen/\(value.id)" else { throw SyncError.invalidData }
                try value.validate()
            case "event":
                let value = try decoder.decode(InjectionEvent.self, from: data)
                guard key == "event/\(value.id)" else { throw SyncError.invalidData }
                try value.validate()
            case "checkIn":
                let value = try decoder.decode(CheckIn.self, from: data)
                guard key == "checkIn/\(value.id)" else { throw SyncError.invalidData }
                try value.validate()
            case "lab":
                let value = try decoder.decode(LabResult.self, from: data)
                guard key == "lab/\(value.id)" else { throw SyncError.invalidData }
                try value.validate()
            case "preference":
                switch key {
                case "preference/levelsNotificationPreferences":
                    _ = try decoder.decode(LevelsNotificationPreferences.self, from: data)
                case "preference/regimenNotificationPreferences":
                    _ = try decoder.decode(RegimenNotificationPreferences.self, from: data)
                case "preference/checkInReminderPreferences":
                    let value = try decoder.decode(CheckInReminderPreferences.self, from: data)
                    guard (0...23).contains(value.hour), (0...59).contains(value.minute) else {
                        throw SyncError.invalidData
                    }
                case "preference/useLatestE2ResultForLevelsCalibration":
                    _ = try decoder.decode(Bool.self, from: data)
                default: throw SyncError.invalidData
                }
            default: throw SyncError.invalidData
            }
        }
    }

    /// Independent edits are combined. If both devices changed the same record,
    /// the already-uploaded version wins, including deletions.
    static func merge(local: Self, remote: Self, baseline: Self) throws -> Self {
        guard local.version == 1, remote.version == 1, baseline.version == 1 else {
            throw SyncError.unsupportedVersion
        }
        var result = remote
        for key in Set(local.records.keys).union(baseline.records.keys) {
            if local.records[key] != baseline.records[key],
               remote.records[key] == baseline.records[key] {
                result.records[key] = local.records[key]
            }
        }
        return result
    }
}
