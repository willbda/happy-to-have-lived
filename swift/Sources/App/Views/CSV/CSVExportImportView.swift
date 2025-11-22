//
// CSVExportImportView.swift
// Written by Claude Code on 2025-11-06
// Updated by Claude Code on 2025-11-15 - Simplified to match DataExporter pattern
//
// PURPOSE:
// Simple data export UI. Uses DataExporter to write raw text dumps.
// Import feature disabled (coming soon).
//

import Dependencies
import Models
import SQLiteData
import Services
import SwiftUI
import UniformTypeIdentifiers

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

    // Import state
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importResult: String = ""

    // Import flow navigation
    @State private var importRecordsActions: [ImportRecord<ActionData>]?
    @State private var importRecordsGoals: [ImportRecord<GoalData>]?
    @State private var importRecordsValues: [ImportRecord<PersonalValueData>]?
    @State private var importRecordsPeriods: [ImportRecord<TimePeriodData>]?
    @State private var finalImportResult: ImportResult?

    var body: some View {
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
                            Label(
                                "Export \(selectedEntityType.displayName)",
                                systemImage: "square.and.arrow.down.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting)
                    .accessibilityLabel(
                        "Export all \(selectedEntityType.displayName) to text file")

                    if !exportResult.isEmpty {
                        Text(exportResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }

            // Import section
            Section("Import Data") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import \(selectedEntityType.displayName) with validation and preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: { showFileImporter = true }) {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                "Import \(selectedEntityType.displayName)",
                                systemImage: "doc.badge.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                    .accessibilityLabel("Import \(selectedEntityType.displayName) from file")

                    if !importResult.isEmpty {
                        Text(importResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Data Export & Import")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [contentType],
            allowsMultipleSelection: false
        ) { result in
            handleImportFileSelection(result)
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportedFileURL.map { TextFileDocument(url: $0) },
            contentType: contentType,
            defaultFilename: defaultFilename
        ) { result in
            handleExportCompletion(result)
        }
        // Import preview sheets
        .sheet(isPresented: .constant(importRecordsActions != nil)) {
            if let records = importRecordsActions {
                ImportPreviewView(
                    records: records,
                    entityTypeName: "Actions",
                    onConfirm: confirmActionsImport,
                    onCancel: { importRecordsActions = nil }
                )
            }
        }
        .sheet(isPresented: .constant(importRecordsGoals != nil)) {
            if let records = importRecordsGoals {
                ImportPreviewView(
                    records: records,
                    entityTypeName: "Goals",
                    onConfirm: confirmGoalsImport,
                    onCancel: { importRecordsGoals = nil }
                )
            }
        }
        .sheet(isPresented: .constant(importRecordsValues != nil)) {
            if let records = importRecordsValues {
                ImportPreviewView(
                    records: records,
                    entityTypeName: "Personal Values",
                    onConfirm: confirmValuesImport,
                    onCancel: { importRecordsValues = nil }
                )
            }
        }
        .sheet(isPresented: .constant(importRecordsPeriods != nil)) {
            if let records = importRecordsPeriods {
                ImportPreviewView(
                    records: records,
                    entityTypeName: "Time Periods",
                    onConfirm: confirmPeriodsImport,
                    onCancel: { importRecordsPeriods = nil }
                )
            }
        }
        // Import result sheet
        .sheet(item: $finalImportResult) { result in
            ImportResultView(
                result: result,
                entityTypeName: selectedEntityType.displayName,
                onDismiss: {
                    finalImportResult = nil
                    importResult = result.summaryMessage
                }
            )
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
                    .appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
                try FileManager.default.createDirectory(
                    at: tempDir, withIntermediateDirectories: true)

                // Export to temp location with selected format
                let exporter = DataExporter(database: database)
                let outputURL = try await exporter.exportToFile(
                    entityType, to: tempDir, format: format)

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

    // MARK: - Import Operations

    private func handleImportFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }

            Task { @MainActor in
                isImporting = true
                defer { isImporting = false }

                do {
                    // Capture entity type and format
                    let entityType = selectedEntityType
                    let format = selectedFormat

                    // Parse and validate using DataImporter
                    let importer = DataImporter(database: database)

                    switch entityType {
                    case .actions:
                        let records = try await importer.previewActions(
                            from: fileURL, format: format)
                        importRecordsActions = records

                    case .goals:
                        let records = try await importer.previewGoals(from: fileURL, format: format)
                        importRecordsGoals = records

                    case .values:
                        let records = try await importer.previewPersonalValues(
                            from: fileURL, format: format)
                        importRecordsValues = records

                    case .terms:
                        let records = try await importer.previewTimePeriods(
                            from: fileURL, format: format)
                        importRecordsPeriods = records
                    }

                    importResult = ""  // Clear any previous errors

                } catch {
                    importResult = "⚠️ Import failed: \(error.localizedDescription)"
                }
            }

        case .failure(let error):
            importResult = "⚠️ File selection failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Confirm Import Handlers

    private func confirmActionsImport(_ records: [ImportRecord<ActionData>]) async throws {
        let importer = DataImporter(database: database)
        let result = try await importer.confirmImportActions(records)

        // Dismiss preview, show result
        importRecordsActions = nil
        finalImportResult = result
    }

    private func confirmGoalsImport(_ records: [ImportRecord<GoalData>]) async throws {
        let importer = DataImporter(database: database)
        let result = try await importer.confirmImportGoals(records)

        importRecordsGoals = nil
        finalImportResult = result
    }

    private func confirmValuesImport(_ records: [ImportRecord<PersonalValueData>]) async throws {
        let importer = DataImporter(database: database)
        let result = try await importer.confirmImportPersonalValues(records)

        importRecordsValues = nil
        finalImportResult = result
    }

    private func confirmPeriodsImport(_ records: [ImportRecord<TimePeriodData>]) async throws {
        let importer = DataImporter(database: database)
        let result = try await importer.confirmImportTimePeriods(records)

        importRecordsPeriods = nil
        finalImportResult = result
    }
}

// MARK: - TextFileDocument

struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .commaSeparatedText, .json] }

    // ✅ CRITICAL: Declare all formats we export to avoid SwiftUI warning
    static var writableContentTypes: [UTType] { [.plainText, .commaSeparatedText, .json] }

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
