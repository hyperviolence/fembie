import Foundation
import Observation

@MainActor
@Observable
final class DataExportViewModel {
    private(set) var isExporting = false
    private(set) var isImporting = false
    private(set) var importRevision = 0

    @ObservationIgnored private let exporter: DataExporter
    @ObservationIgnored private let importer: DataImporter

    init(repository: any TrackingRepository) {
        exporter = DataExporter(repository: repository)
        importer = DataImporter(repository: repository)
    }

    func importData(_ data: Data) async throws {
        guard !isImporting else { throw CancellationError() }
        isImporting = true
        defer { isImporting = false }
        try await importer.importData(data)
        importRevision += 1
    }

    func makeFile() async throws -> DataExportFile {
        guard !isExporting else {
            throw CancellationError()
        }

        isExporting = true
        defer { isExporting = false }
        return try await exporter.makeFile()
    }
}
