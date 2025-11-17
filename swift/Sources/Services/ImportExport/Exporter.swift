//
// Exporter.swift
// Written by Claude Code on 2025-11-15
// Updated to use canonical types on 2025-11-15
//
// PURPOSE:
// Data export service - handles repository dispatch and format encoding.
//
// PATTERN:
// - Repositories provide data via fetchAll() (canonical types)
// - DataExporter handles both JSON and CSV formatting
// - Returns Data (not files) - caller handles file I/O
// - ActionData is Codable for both JSON export and CSV formatting
//

import Foundation
import Models
import SQLiteData

public enum DomainModel: Sendable {
    case actions
    case goals
    case values
    case terms

    public var displayName: String {
        switch self {
        case .actions: return "Actions"
        case .goals: return "Goals"
        case .values: return "Values"
        case .terms: return "Terms"
        }
    }
}

public enum ExportFormat: Sendable {
    case json
    case csv

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }
}

public final class DataExporter {
    private let database: any DatabaseWriter
    private let csvFormatter = CSVFormatter()

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Export entity data in specified format
    /// - Parameters:
    ///   - model: Which entity type to export
    ///   - format: JSON or CSV format
    ///   - startDate: Optional start of date range filter
    ///   - endDate: Optional end of date range filter
    /// - Returns: Formatted data ready to write
    public func export(
        _ model: DomainModel,
        format: ExportFormat,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> Data {
        switch model {
        case .actions:
            let repository = ActionRepository(database: database)
            let actions = try await repository.fetchForExport(from: startDate, to: endDate)
            return try formatData(actions, format: format, csvFormatter: csvFormatter.formatActions)

        case .goals:
            let repository = GoalRepository(database: database)
            // Use canonical GoalData directly for both display and export
            let goals = try await repository.fetchForExport(from: startDate, to: endDate)
            return try formatData(goals, format: format, csvFormatter: csvFormatter.formatGoals)

        case .values:
            let repository = PersonalValueRepository(database: database)
            // Use canonical PersonalValueData directly for both display and export
            let values = try await repository.fetchForExport(from: startDate, to: endDate)
            return try formatData(values, format: format, csvFormatter: csvFormatter.formatValues)

        case .terms:
            let repository = TimePeriodRepository(database: database)
            let terms = try await repository.fetchAll()
            return try formatData(terms, format: format, csvFormatter: csvFormatter.formatTerms)
        }
    }

    /// Export entity data to file
    /// - Parameters:
    ///   - model: Which entity type to export
    ///   - directory: Output directory
    ///   - format: JSON or CSV format
    ///   - startDate: Optional start of date range filter
    ///   - endDate: Optional end of date range filter
    /// - Returns: URL of created file
    public func exportToFile(
        _ model: DomainModel,
        to directory: URL,
        format: ExportFormat,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> URL {
        let data = try await export(model, format: format, from: startDate, to: endDate)

        let filename = "\(model.displayName.lowercased())_export.\(format.fileExtension)"
        let outputURL = directory.appendingPathComponent(filename)

        try data.write(to: outputURL)

        print("✓ Exported \(model.displayName) to: \(outputURL.path)")
        return outputURL
    }

    /// Export all entity types to separate files
    /// - Parameters:
    ///   - directory: Output directory
    ///   - format: JSON or CSV format
    ///   - startDate: Optional start of date range filter
    ///   - endDate: Optional end of date range filter
    /// - Returns: URLs of all created files
    public func exportAll(
        to directory: URL,
        format: ExportFormat,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [URL] {
        let actionsURL = try await exportToFile(.actions, to: directory, format: format, from: startDate, to: endDate)
        let goalsURL = try await exportToFile(.goals, to: directory, format: format, from: startDate, to: endDate)
        let valuesURL = try await exportToFile(.values, to: directory, format: format, from: startDate, to: endDate)
        let termsURL = try await exportToFile(.terms, to: directory, format: format, from: startDate, to: endDate)

        return [actionsURL, goalsURL, valuesURL, termsURL]
    }

    // MARK: - Private Helpers

    /// Format data based on export format
    private func formatData<T: Encodable>(
        _ data: T,
        format: ExportFormat,
        csvFormatter: (T) throws -> Data
    ) throws -> Data {
        switch format {
        case .json:
            return try encodeJSON(data)
        case .csv:
            return try csvFormatter(data)
        }
    }

    /// Encode data to JSON
    private func encodeJSON<T: Encodable>(_ data: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(data)
    }
}
