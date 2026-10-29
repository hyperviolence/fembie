import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct DataExport: Codable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let appVersion: String?
    let regimens: [Regimen]
    let injectionEvents: [InjectionEvent]
    let checkIns: [CheckIn]

    init(formatVersion: Int = Self.currentFormatVersion, appVersion: String? = nil,
         regimens: [Regimen], injectionEvents: [InjectionEvent], checkIns: [CheckIn]) {
        self.formatVersion = formatVersion
        self.appVersion = appVersion
        self.regimens = regimens
        self.injectionEvents = injectionEvents
        self.checkIns = checkIns
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, appVersion, regimen, regimens, injectionEvents, checkIns
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        if container.contains(.regimens) {
            regimens = try container.decode([Regimen].self, forKey: .regimens)
        } else if let regimen = try container.decodeIfPresent(Regimen.self, forKey: .regimen) {
            // Early version 1 exports stored the only regimen as a single object.
            regimens = [regimen]
        } else {
            regimens = []
        }
        injectionEvents = try container.decode([InjectionEvent].self, forKey: .injectionEvents)
        checkIns = try container.decode([CheckIn].self, forKey: .checkIns)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encode(regimens, forKey: .regimens)
        try container.encode(injectionEvents, forKey: .injectionEvents)
        try container.encode(checkIns, forKey: .checkIns)
    }
}

nonisolated struct DataExportFile: Transferable, Sendable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            export.data
        }
    }
}

nonisolated struct DataExporter: Sendable {
    private let repository: any TrackingRepository

    init(repository: any TrackingRepository) {
        self.repository = repository
    }

    func makeFile(exportedAt: Date = Date(), calendar: Calendar = .current,
                  appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) async throws -> DataExportFile {
        async let regimens = repository.regimens()
        async let injectionEvents = repository.injectionEvents()
        async let checkIns = repository.checkIns()

        let export = try await DataExport(
            appVersion: appVersion,
            regimens: regimens,
            injectionEvents: injectionEvents,
            checkIns: checkIns
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try DataExportFile(
            data: encoder.encode(export),
            fileName: Self.fileName(for: exportedAt, calendar: calendar)
        )
    }

    static func fileName(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = formatted(components.year, length: 4)
        let month = formatted(components.month, length: 2)
        let day = formatted(components.day, length: 2)
        let hour = formatted(components.hour, length: 2)
        let minute = formatted(components.minute, length: 2)
        let second = formatted(components.second, length: 2)
        return "fembie-data-exported-\(year)-\(month)-\(day)-\(hour)-\(minute)-\(second).json"
    }

    private static func formatted(_ value: Int?, length: Int) -> String {
        (value ?? 0).formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .grouping(.never)
                .precision(.integerLength(length))
        )
    }
}
