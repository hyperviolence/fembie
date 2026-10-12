import Foundation
import Observation

@MainActor
@Observable
final class DataExportViewModel {
    private(set) var isExporting = false

    @ObservationIgnored private let exporter: DataExporter

    init(repository: any TrackingRepository) {
        exporter = DataExporter(repository: repository)
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
