import SwiftUI
import UniformTypeIdentifiers

struct SettingsDataExportSection: View {
    @Environment(DataExportViewModel.self) private var model
    @State private var exportFile: DataExportFile?
    @State private var pendingImport: Data?
    @State private var isFileExporterPresented = false
    @State private var isFileImporterPresented = false
    @State private var isImportConfirmationPresented = false
    @State private var showError = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showImportSuccess = false

    var body: some View {
        Section {
            Button("Export data...", systemImage: "tray.and.arrow.up") {
                prepareExport()
            }
            .disabled(model.isExporting || model.isImporting)

            Button("Import data...", systemImage: "tray.and.arrow.down") {
                isFileImporterPresented = true
            }
            .disabled(model.isExporting || model.isImporting)
        } footer: {
            if model.isExporting {
                Text("Preparing export…")
            } else if model.isImporting {
                Text("Validating and importing…")
            } else {
                Text("Importing replaces existing regimen, injection, and check-in data.")
            }
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            item: exportFile,
            contentTypes: [.json],
            defaultFilename: exportFile?.fileName
        ) { result in
            if case .failure(let error) = result {
                present(error, title: "Could not export data")
            }
            exportFile = nil
        } onCancellation: {
            exportFile = nil
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.json]) { result in
            receiveImport(result)
        }
        .confirmationDialog(
            "Replace existing data?",
            isPresented: $isImportConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Import and replace data", role: .destructive) {
                performImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text("The selected file will be strictly validated before any existing data is replaced. This cannot be undone.")
        }
        .alert(errorTitle, isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Import complete", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your regimen, injection, and check-in data was imported.")
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
                present(error, title: "Could not export data")
            }
        }
    }

    private func receiveImport(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            pendingImport = try Data(contentsOf: url, options: .mappedIfSafe)
            isImportConfirmationPresented = true
        } catch {
            present(error, title: "Could not read import file")
        }
    }

    private func performImport() {
        guard let pendingImport else { return }
        self.pendingImport = nil
        Task {
            do {
                try await model.importData(pendingImport)
                showImportSuccess = true
            } catch is CancellationError {
                return
            } catch {
                present(error, title: "Could not import data")
            }
        }
    }

    private func present(_ error: any Error, title: String) {
        errorTitle = title
        errorMessage = error.localizedDescription
        showError = true
    }
}
