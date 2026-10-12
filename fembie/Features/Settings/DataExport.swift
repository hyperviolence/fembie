import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct DataExport: Codable, Sendable {
    let regimens: [Regimen]
    let injectionEvents: [InjectionEvent]
    let checkIns: [CheckIn]
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

    func makeFile(exportedAt: Date = Date(), calendar: Calendar = .current) async throws -> DataExportFile {
        async let regimens = repository.regimens()
        async let injectionEvents = repository.injectionEvents()
        async let checkIns = repository.checkIns()

        let export = try await DataExport(
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
