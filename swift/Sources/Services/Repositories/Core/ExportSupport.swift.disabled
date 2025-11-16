//
// ExportSupport.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Shared utilities for data export functionality across repositories.
// Provides consistent date filtering, formatting, and CSV/JSON helpers.
//
// DESIGN:
// - DateFilter: Build SQL WHERE clauses for date range filtering
// - ExportDateFormatter: Consistent ISO8601 formatting
// - CSVEscaper: Handle special characters in CSV export
// - Export protocols: Define common export patterns
//

import Foundation
import Models
import SQLiteData
import GRDB

// MARK: - Date Filtering

/// Date filter builder for export queries
///
/// PATTERN: Encapsulates date range filtering logic used across all repositories.
/// Generates SQL WHERE clauses with proper parameter binding.
///
/// USAGE:
/// ```swift
/// let filter = DateFilter(startDate: from, endDate: to)
/// let (whereClause, args) = filter.buildWhereClause(dateColumn: "logTime")
/// let sql = baseQuery + whereClause
/// ```
public struct DateFilter {
    public let startDate: Date?
    public let endDate: Date?

    /// Initialize with optional date bounds
    /// - Parameters:
    ///   - startDate: Start of range (inclusive), nil for unbounded
    ///   - endDate: End of range (inclusive), nil for unbounded
    public init(startDate: Date? = nil, endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Build SQL WHERE clause for date filtering
    /// - Parameter dateColumn: The column to filter on (e.g., "logTime", "a.startTime")
    /// - Returns: Tuple of (SQL WHERE clause, arguments array)
    ///
    /// Examples:
    /// - Both dates: "WHERE logTime >= ? AND logTime <= ?"
    /// - Start only: "WHERE logTime >= ?"
    /// - End only: "WHERE logTime <= ?"
    /// - Neither: "" (empty string)
    public func buildWhereClause(dateColumn: String) -> (sql: String, arguments: [any DatabaseValueConvertible]) {
        var whereClauses: [String] = []
        var arguments: [any DatabaseValueConvertible] = []

        if let start = startDate {
            whereClauses.append("\(dateColumn) >= ?")
            arguments.append(start)
        }

        if let end = endDate {
            whereClauses.append("\(dateColumn) <= ?")
            arguments.append(end)
        }

        if whereClauses.isEmpty {
            return ("", [])
        } else {
            return ("WHERE " + whereClauses.joined(separator: " AND "), arguments)
        }
    }

    /// Build WHERE clause with additional conditions
    /// - Parameters:
    ///   - dateColumn: The date column to filter on
    ///   - additionalConditions: Extra WHERE conditions to AND with date filter
    /// - Returns: Tuple of (SQL WHERE clause, arguments array)
    ///
    /// Example:
    /// ```swift
    /// let (where, args) = filter.buildWhereClause(
    ///     dateColumn: "logTime",
    ///     additionalConditions: ["status = 'active'", "priority > 5"]
    /// )
    /// // Result: "WHERE logTime >= ? AND status = 'active' AND priority > 5"
    /// ```
    public func buildWhereClause(
        dateColumn: String,
        additionalConditions: [String]
    ) -> (sql: String, arguments: [any DatabaseValueConvertible]) {
        let (dateWhere, dateArgs) = buildWhereClause(dateColumn: dateColumn)

        var allConditions = additionalConditions

        // Extract date conditions without "WHERE" prefix
        if !dateWhere.isEmpty {
            let dateConditions = dateWhere.replacingOccurrences(of: "WHERE ", with: "")
            allConditions.insert(dateConditions, at: 0)
        }

        if allConditions.isEmpty {
            return ("", [])
        } else {
            return ("WHERE " + allConditions.joined(separator: " AND "), dateArgs)
        }
    }
}

// MARK: - Date Formatting

/// ISO8601 date formatter for exports
///
/// PATTERN: Singleton formatter for consistent date representation in exports.
/// Thread-safe through internal synchronization.
public struct ExportDateFormatter {
    /// Shared formatter instance (thread-safe)
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Shared formatter with fractional seconds
    private static let formatterWithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Format a date as ISO8601 string
    /// - Parameter date: The date to format
    /// - Returns: ISO8601 formatted string (e.g., "2025-11-15T10:30:00Z")
    public static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// Format an optional date as ISO8601 string
    /// - Parameter date: The optional date to format
    /// - Returns: ISO8601 formatted string or empty string if nil
    public static func format(_ date: Date?) -> String {
        date.map { format($0) } ?? ""
    }

    /// Parse an ISO8601 date string
    /// - Parameter dateString: The string to parse
    /// - Returns: Parsed Date or nil if invalid
    public static func parse(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        // Try with fractional seconds first
        if let date = formatterWithFractionalSeconds.date(from: dateString) {
            return date
        }

        // Fall back to without fractional seconds
        return formatter.date(from: dateString)
    }
}

// MARK: - CSV Support

/// CSV field escaper for safe export
///
/// PATTERN: Handles special characters in CSV fields according to RFC 4180.
/// Ensures data integrity when fields contain commas, quotes, or newlines.
public struct CSVEscaper {
    /// Escape a string value for CSV format
    /// - Parameter value: The value to escape
    /// - Returns: Properly escaped CSV field
    ///
    /// Rules:
    /// - Fields with comma, newline, or quote: wrap in quotes
    /// - Quotes within field: double them ("" for ")
    /// - Null/empty: return as-is
    public static func escape(_ value: String) -> String {
        // Check if escaping is needed
        if value.contains(",") || value.contains("\n") || value.contains("\"") || value.contains("\r") {
            // Escape quotes by doubling them
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// Escape an optional string value for CSV format
    /// - Parameter value: The optional value to escape
    /// - Returns: Escaped string or empty string if nil
    public static func escape(_ value: String?) -> String {
        value.map { escape($0) } ?? ""
    }

    /// Convert an array to semicolon-delimited string for CSV
    /// - Parameter array: Array of string-convertible values
    /// - Returns: Semicolon-separated string
    ///
    /// Example: ["goal1", "goal2", "goal3"] → "goal1;goal2;goal3"
    public static func joinArray<T: CustomStringConvertible>(_ array: [T]) -> String {
        array.map { $0.description }.joined(separator: ";")
    }

    /// Convert UUID array to semicolon-delimited string
    /// - Parameter uuids: Array of UUIDs
    /// - Returns: Semicolon-separated UUID strings
    public static func joinUUIDs(_ uuids: [UUID]) -> String {
        uuids.map { $0.uuidString }.joined(separator: ";")
    }

    /// Escape and format a JSON object for CSV embedding
    /// - Parameter encodable: Object to encode as JSON
    /// - Returns: Escaped JSON string suitable for CSV field
    ///
    /// Encodes object as JSON then escapes for CSV field.
    /// Useful for complex nested data in CSV exports.
    public static func embedJSON<T: Encodable>(_ encodable: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Consistent output
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(encodable)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return "\"\""
        }

        // JSON in CSV needs escaping
        return escape(jsonString)
    }
}

// MARK: - Export Protocols

/// Protocol for entities that support CSV export
///
/// Implement this to provide CSV row generation for an entity.
public protocol CSVExportable {
    /// Generate CSV header row
    static var csvHeader: String { get }

    /// Generate CSV data row for this instance
    var csvRow: String { get }
}

/// Protocol for entities that support custom JSON export
///
/// Use when default Codable encoding isn't sufficient.
public protocol JSONExportable: Codable {
    /// Custom JSON representation for export
    func exportJSON() throws -> Data
}

// Default implementation uses standard Codable
public extension JSONExportable {
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

// MARK: - Batch Export Support

/// Configuration for batch export operations
///
/// Use when exporting large datasets that need pagination.
public struct BatchExportConfig {
    public let batchSize: Int
    public let includeHeader: Bool
    public let format: ExportFormat

    public enum ExportFormat {
        case csv
        case json
        case jsonLines  // One JSON object per line
    }

    public init(
        batchSize: Int = 1000,
        includeHeader: Bool = true,
        format: ExportFormat = .csv
    ) {
        self.batchSize = batchSize
        self.includeHeader = includeHeader
        self.format = format
    }
}

/// Result of a batch export operation
public struct BatchExportResult {
    public let data: Data
    public let recordCount: Int
    public let hasMore: Bool
    public let nextOffset: Int?

    public init(
        data: Data,
        recordCount: Int,
        hasMore: Bool,
        nextOffset: Int? = nil
    ) {
        self.data = data
        self.recordCount = recordCount
        self.hasMore = hasMore
        self.nextOffset = nextOffset
    }
}

// MARK: - Export Filename Builder

/// Generate consistent export filenames
public struct ExportFilename {
    /// Build a timestamped export filename
    /// - Parameters:
    ///   - prefix: The entity type (e.g., "actions", "goals")
    ///   - format: The file extension (e.g., "csv", "json")
    ///   - date: The export date (defaults to now)
    /// - Returns: Filename like "actions_export_2025-11-15_103045.csv"
    public static func build(
        prefix: String,
        format: String,
        date: Date = Date()
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: date)
        return "\(prefix)_export_\(timestamp).\(format)"
    }

    /// Build a filename for date-ranged exports
    /// - Parameters:
    ///   - prefix: The entity type
    ///   - startDate: Range start date
    ///   - endDate: Range end date
    ///   - format: File extension
    /// - Returns: Filename like "actions_2025-10-01_to_2025-11-15.csv"
    public static func buildWithRange(
        prefix: String,
        startDate: Date?,
        endDate: Date?,
        format: String
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var parts = [prefix]

        if let start = startDate {
            parts.append(formatter.string(from: start))
        }

        if startDate != nil || endDate != nil {
            parts.append("to")
        }

        if let end = endDate {
            parts.append(formatter.string(from: end))
        } else if startDate != nil {
            parts.append("present")
        }

        if startDate == nil && endDate == nil {
            parts.append("all")
        }

        return parts.joined(separator: "_") + ".\(format)"
    }
}