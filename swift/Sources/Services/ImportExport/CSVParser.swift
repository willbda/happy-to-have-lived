//
// CSVParser.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// RFC 4180 compliant CSV parser for import functionality.
//
// FEATURES:
// - Handles quoted fields with commas/newlines
// - Handles escaped quotes ("" → ")
// - Validates header row
// - Returns structured data: [[String: String]]
//
// PATTERN:
// - State machine parser (not simple split)
// - Symmetrical with CSVFormatter (can parse what we export)
// - No database access (pure parsing logic)
//

import Foundation
import Models

/// RFC 4180 compliant CSV parser
///
/// **Usage**:
/// ```swift
/// let parser = CSVParser()
/// let rows = try parser.parse(csvText)
/// // Returns: [[String: String]] where keys are column headers
/// ```
///
/// **Handles**:
/// - Quoted fields: `"text, with, commas"`
/// - Escaped quotes: `"He said ""hello"""`
/// - Newlines in fields: `"Line 1\nLine 2"`
/// - Empty fields: `value1,,value3`
public struct CSVParser {

    public init() {}

    // MARK: - Public API

    /// Parse CSV text into array of dictionaries
    ///
    /// - Parameter csvText: Raw CSV string
    /// - Returns: Array of row dictionaries (header → value)
    /// - Throws: ValidationError if parsing fails
    public func parse(_ csvText: String) throws -> [[String: String]] {
        let lines = splitIntoRecords(csvText)

        guard !lines.isEmpty else {
            throw ValidationError.databaseConstraint("CSV file is empty")
        }

        // Parse header row
        let headerFields = try parseRecord(lines[0], rowNumber: 1)

        guard !headerFields.isEmpty else {
            throw ValidationError.databaseConstraint("CSV header row is empty")
        }

        // Parse data rows
        var rows: [[String: String]] = []
        for (index, line) in lines.dropFirst().enumerated() {
            let rowNumber = index + 2  // +2 because: 0-indexed + skipped header
            let fields = try parseRecord(line, rowNumber: rowNumber)

            guard fields.count == headerFields.count else {
                throw ValidationError.databaseConstraint(
                    "Row \(rowNumber): Expected \(headerFields.count) fields, got \(fields.count)"
                )
            }

            // Build dictionary: header → value
            var row: [String: String] = [:]
            for (header, value) in zip(headerFields, fields) {
                row[header] = value
            }
            rows.append(row)
        }

        return rows
    }

    // MARK: - Record Splitting

    /// Split CSV text into records (respecting quoted newlines)
    ///
    /// **Challenge**: Newlines within quoted fields should NOT split records.
    /// Example: `"Line 1\nLine 2",value2` is ONE record, not two.
    ///
    /// **Solution**: State machine tracking whether we're inside quotes.
    private func splitIntoRecords(_ csvText: String) -> [String] {
        var records: [String] = []
        var currentRecord = ""
        var insideQuotes = false

        for char in csvText {
            switch char {
            case "\"":
                insideQuotes.toggle()
                currentRecord.append(char)

            case "\n", "\r":
                if insideQuotes {
                    // Newline inside quoted field - part of current record
                    currentRecord.append(char)
                } else {
                    // Newline outside quotes - end of record
                    if !currentRecord.isEmpty {
                        records.append(currentRecord)
                        currentRecord = ""
                    }
                }

            default:
                currentRecord.append(char)
            }
        }

        // Don't forget the last record (if file doesn't end with newline)
        if !currentRecord.isEmpty {
            records.append(currentRecord)
        }

        return records
    }

    // MARK: - Field Parsing

    /// Parse a single CSV record into fields
    ///
    /// **RFC 4180 Rules**:
    /// - Fields separated by commas
    /// - Fields may be quoted with `"`
    /// - Quotes within quoted fields are escaped as `""`
    /// - Commas/newlines within quoted fields don't split the field
    ///
    /// **Example**:
    /// ```
    /// "He said ""hello""",value2,"text, with, commas"
    /// → ["He said \"hello\"", "value2", "text, with, commas"]
    /// ```
    private func parseRecord(_ record: String, rowNumber: Int) throws -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var chars = Array(record)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            switch char {
            case "\"":
                if insideQuotes {
                    // Check for escaped quote ("" → ")
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 1  // Skip next quote
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    // Start of quoted field
                    insideQuotes = true
                }

            case ",":
                if insideQuotes {
                    // Comma inside quoted field - part of value
                    currentField.append(char)
                } else {
                    // Comma outside quotes - field separator
                    fields.append(currentField)
                    currentField = ""
                }

            default:
                currentField.append(char)
            }

            i += 1
        }

        // Don't forget the last field
        fields.append(currentField)

        // Validate: if we end inside quotes, the CSV is malformed
        if insideQuotes {
            throw ValidationError.databaseConstraint(
                "Row \(rowNumber): Unclosed quoted field"
            )
        }

        return fields
    }
}

// MARK: - Helper Extensions

extension CSVParser {

    /// Parse semicolon-separated UUIDs
    ///
    /// **Format**: `uuid1;uuid2;uuid3`
    /// **Empty**: `` (empty string)
    ///
    /// Used for: Goal IDs, Value IDs in CSV exports
    public static func parseSemicolonUUIDs(_ text: String) throws -> [UUID] {
        guard !text.isEmpty else { return [] }

        let uuidStrings = text.split(separator: ";").map(String.init)
        var uuids: [UUID] = []

        for uuidString in uuidStrings {
            guard let uuid = UUID(uuidString: uuidString) else {
                throw ValidationError.databaseConstraint("Invalid UUID: \(uuidString)")
            }
            uuids.append(uuid)
        }

        return uuids
    }

    /// Parse ISO8601 date string
    ///
    /// **Format**: `2025-11-16T12:30:00Z` (matches export format)
    ///
    /// Uses ISO8601DateFormatter (symmetrical with export).
    public static func parseDate(_ text: String) throws -> Date {
        guard !text.isEmpty else {
            throw ValidationError.databaseConstraint("Date field is empty")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first
        if let date = formatter.date(from: text) {
            return date
        }

        // Fall back to without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: text) {
            return date
        }

        throw ValidationError.databaseConstraint("Invalid date format: \(text)")
    }

    /// Parse optional ISO8601 date string
    ///
    /// Returns nil for empty string, throws for invalid format.
    public static func parseOptionalDate(_ text: String) throws -> Date? {
        guard !text.isEmpty else { return nil }
        return try parseDate(text)
    }

    /// Parse nested JSON from CSV field
    ///
    /// **Context**: Export uses JSON-in-CSV for complex nested structures.
    /// Example: Measurements column contains `"[{\"measureId\":\"...\"}]"`
    ///
    /// **Pattern**: Field is already a JSON string, just decode it.
    public static func parseNestedJSON<T: Decodable>(_ jsonString: String, as type: [T].Type) throws -> [T] {
        guard !jsonString.isEmpty else { return [] }

        guard let data = jsonString.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid UTF-8 in JSON field")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601  // Match export format

        do {
            return try decoder.decode([T].self, from: data)
        } catch {
            throw ValidationError.databaseConstraint(
                "Failed to parse JSON: \(error.localizedDescription)"
            )
        }
    }
}
