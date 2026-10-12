import SwiftUI
import UniformTypeIdentifiers

struct SettingsDataExportSection: View {
    @Environment(DataExportViewModel.self) private var model
    @State private var exportFile: DataExportFile?
    @State private var isFileExporterPresented = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Section {
            Button("Export data...", systemImage: "tray.and.arrow.up") {
                prepareExport()
            }
            .disabled(model.isExporting)
        } footer: {
            if model.isExporting {
                Text("Preparing export…")
            }
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            item: exportFile,
            contentTypes: [.json],
            defaultFilename: exportFile?.fileName
        ) { result in
            if case .failure(let error) = result {
                present(error)
            }
            exportFile = nil
        } onCancellation: {
            exportFile = nil
        }
        .alert("Could not export data", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func prepareExport() {
        Task {
            do {
                exportFile = try await model.makeFile()
                isFileExporterPresented = true
            } catch is CancellationError {
                return
            } catch {
                present(error)
            }
        }
    }

    private func present(_ error: any Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
