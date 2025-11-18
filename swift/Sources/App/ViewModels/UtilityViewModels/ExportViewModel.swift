//
// ExportViewModel.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Orchestrates data export operations - UI state management only.
//
// PATTERN:
// - Repositories provide data via fetchForExport()
// - Services handle formatting (DataExporter for JSON, CSVFormatter for CSV)
// - ViewModel manages UI state (progress, errors)
//

import Foundation
import Models
import Services
import SQLiteData
import Dependencies

/// Entity types available for export
public enum ExportEntityType: String, CaseIterable {
    case actions = "Actions"
    case goals = "Goals"
    case personalValues = "Personal Values"
    case terms = "Terms"

    var displayName: String { rawValue }
}

/// Export format options
public enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"

    var displayName: String { rawValue }
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }
}

/// View model for data export functionality
///
/// PATTERN: UI state management only
/// - DataExporter handles all repository dispatch and formatting
/// - This VM manages: progress tracking, error display, filename generation
@Observable
@MainActor
public final class ExportViewModel {

    // MARK: - State Properties

    var isExporting: Bool = false
    var exportProgress: Double = 0.0
    var errorMessage: String?

    var hasError: Bool { errorMessage != nil }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    // MARK: - Initialization

    public init() {}

    // MARK: - Export Methods

    /// Export data in the specified format
    /// - Parameters:
    ///   - entityType: Which entity to export
    ///   - format: JSON or CSV format
    ///   - startDate: Optional start of date range
    ///   - endDate: Optional end of date range
    /// - Returns: Exported data and suggested filename
    public func exportData(
        entityType: ExportEntityType,
        format: ExportFormat,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> (data: Data, filename: String) {
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil

        defer { isExporting = false }

        do {
            exportProgress = 0.3

            // Delegate all business logic to DataExporter
            let exporter = DataExporter(database: database)
            let domainModel = mapEntityTypeToDomainModel(entityType)
            let exportFormat = mapToExportFormat(format)

            exportProgress = 0.6

            let data = try await exporter.export(
                domainModel,
                format: exportFormat,
                from: startDate,
                to: endDate
            )

            exportProgress = 1.0

            // Generate filename with timestamp
            let filename = generateFilename(entityType: entityType, format: format)

            return (data, filename)

        } catch let error as ValidationError {
            errorMessage = error.userMessage
            throw error
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Map UI entity type to service domain model
    private func mapEntityTypeToDomainModel(_ entityType: ExportEntityType) -> DomainModel {
        switch entityType {
        case .actions: return .actions
        case .goals: return .goals
        case .personalValues: return .values
        case .terms: return .terms
        }
    }

    /// Map UI format to service export format
    private func mapToExportFormat(_ format: ExportFormat) -> Services.ExportFormat {
        switch format {
        case .json: return .json
        case .csv: return .csv
        }
    }

    /// Generate timestamped filename
    private func generateFilename(entityType: ExportEntityType, format: ExportFormat) -> String {
        let baseFilename: String
        switch entityType {
        case .actions: baseFilename = "actions"
        case .goals: baseFilename = "goals"
        case .personalValues: baseFilename = "personal_values"
        case .terms: baseFilename = "terms"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        return "\(baseFilename)_export_\(timestamp).\(format.fileExtension)"
    }
}