//
// CSVExportImportView.swift
// Written by Claude Code on 2025-11-06
// Updated by Claude Code on 2025-11-15 - Simplified to match DataExporter pattern
//
// PURPOSE:
// Simple data export UI. Uses DataExporter to write raw text dumps.
// Import feature disabled (coming soon).
//

import SwiftUI
import SQLiteData
import Dependencies
import Services

struct CSVExportImportView: View {
    @Dependency(\.defaultDatabase) private var database

    // MARK: - Entity Type Selection

    @State private var selectedEntityType: DomainModel = .actions
    @State private var selectedFormat: Services.ExportFormat = .csv

    // MARK: - State

    @State private var exportResult: String = ""
    @State private var isExporting = false
    @State private var showImportAlert = false
    @State private var showFileExporter = false
    @State private var exportedFileURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                // Entity type picker
                Section {
                    Picker("Data Type", selection: $selectedEntityType) {
                        Text("Actions").tag(DomainModel.actions)
                        Text("Goals").tag(DomainModel.goals)
                        Text("Values").tag(DomainModel.values)
                        Text("Terms").tag(DomainModel.terms)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select data type to export")
                } header: {
                    Text("Export Type")
                }

                // Format picker
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        Text("CSV").tag(Services.ExportFormat.csv)
                        Text("JSON").tag(Services.ExportFormat.json)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select export format")
                } header: {
                    Text("Export Format")
                } footer: {
                    Text("CSV: Spreadsheet-compatible, JSON: Structured data with full details")
                        .font(.caption)
                }

                // Export section
                Section("Export Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export all \(selectedEntityType.displayName) as raw text")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(action: exportData) {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Export \(selectedEntityType.displayName)", systemImage: "square.and.arrow.down.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting)
                        .accessibilityLabel("Export all \(selectedEntityType.displayName) to text file")

                        if !exportResult.isEmpty {
                            Text(exportResult)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }

                // Import section (disabled)
                Section("Import Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CSV import with validation and preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(action: { showImportAlert = true }) {
                            Label("Import from CSV", systemImage: "doc.badge.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Import data from CSV file")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Data Export & Import")
        }
        .alert("Coming Soon", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("CSV import with validation and preview is currently under development. For now, you can export data as text files for backup purposes.")
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportedFileURL.map { TextFileDocument(url: $0) },
            contentType: contentType,
            defaultFilename: defaultFilename
        ) { result in
            handleExportCompletion(result)
        }
    }

    // MARK: - Computed Properties

    private var defaultFilename: String {
        "\(selectedEntityType.displayName.lowercased())_export.\(selectedFormat.fileExtension)"
    }

    private var contentType: UTType {
        switch selectedFormat {
        case .json:
            return .json
        case .csv:
            return .commaSeparatedText
        }
    }

    // MARK: - Export Operations

    private func exportData() {
        Task { @MainActor in
            isExporting = true
            defer { isExporting = false }

            do {
                // Capture the entity type and format before async work
                let entityType = selectedEntityType
                let format = selectedFormat

                // Create temporary directory for export
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                // Export to temp location with selected format
                let exporter = DataExporter(database: database)
                let outputURL = try await exporter.exportToFile(entityType, to: tempDir, format: format)

                // Store URL and show file exporter
                exportedFileURL = outputURL
                showFileExporter = true

            } catch {
                exportResult = "⚠️ Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            exportResult = """
            ✓ Exported to:
            - \(url.lastPathComponent)
            """
        case .failure(let error):
            exportResult = "⚠️ Save failed: \(error.localizedDescription)"
        }

        // Clean up temp file
        if let tempURL = exportedFileURL {
            try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        }
        exportedFileURL = nil
    }
}

// MARK: - TextFileDocument

import UniformTypeIdentifiers

struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        fatalError("Reading not supported")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url)
    }
}

// MARK: - Preview

#Preview {
    CSVExportImportView()
        .frame(width: 600, height: 500)
}
