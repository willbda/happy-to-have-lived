//
// JSONParser.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// JSON parser for import functionality.
//
// PATTERN:
// - Simple JSONDecoder wrapper
// - Configured with ISO8601 date strategy (matches export)
// - Decodes directly to canonical Data types (ActionData, GoalData, etc.)
// - Symmetrical with DataExporter's JSON encoding
//

import Foundation
import Models

/// JSON parser for importing canonical Data types
///
/// **Usage**:
/// ```swift
/// let parser = JSONParser()
/// let actions = try parser.parse(jsonData, as: [ActionData].self)
/// ```
///
/// **Pattern**: Canonical Data types are Codable, so we can decode directly.
/// No intermediate parsing needed (unlike CSV).
public struct JSONParser {

    private let decoder: JSONDecoder

    public init() {
        self.decoder = JSONDecoder()

        // Configure date decoding to match export format
        // DataExporter uses: encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Parse JSON data into array of entities
    ///
    /// **Type Safety**: Leverages Swift's Codable for automatic parsing.
    ///
    /// - Parameters:
    ///   - data: JSON data from file
    ///   - type: The array type to decode (e.g., [ActionData].self)
    /// - Returns: Decoded array of entities
    /// - Throws: ValidationError if parsing fails
    public func parse<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch {
            throw ValidationError.databaseConstraint(
                "Failed to parse JSON: \(error.localizedDescription)"
            )
        }
    }

    /// Parse JSON from file URL
    ///
    /// **Convenience**: Load and parse in one step.
    public func parse<T: Decodable>(fileURL: URL, as type: T.Type) throws -> T {
        do {
            let data = try Data(contentsOf: fileURL)
            return try parse(data, as: type)
        } catch let error as ValidationError {
            throw error  // Re-throw validation errors as-is
        } catch {
            throw ValidationError.databaseConstraint(
                "Failed to read file: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Error Mapping

    /// Map DecodingError to user-friendly ValidationError
    ///
    /// **Pattern**: Convert technical JSON decoding errors to user-friendly messages.
    private func mapDecodingError(_ error: DecodingError) -> ValidationError {
        switch error {
        case .typeMismatch(_, let context):
            return .databaseConstraint(
                "Invalid data type at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            )

        case .valueNotFound(_, let context):
            return .missingRequiredField(
                "Missing required field: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            )

        case .keyNotFound(let key, let context):
            return .missingRequiredField(
                "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            )

        case .dataCorrupted(let context):
            // Check if it's a date parsing error
            if context.debugDescription.contains("date") {
                return .invalidDateRange(
                    "Invalid date format at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                )
            }
            return .databaseConstraint(
                "Corrupted data at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            )

        @unknown default:
            return .databaseConstraint("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
}

// MARK: - Type-Safe Convenience Methods

extension JSONParser {

    /// Parse Actions from JSON file
    ///
    /// **Type Safety**: Explicit method prevents type confusion.
    public func parseActions(from fileURL: URL) throws -> [ActionData] {
        try parse(fileURL: fileURL, as: [ActionData].self)
    }

    /// Parse Goals from JSON file
    public func parseGoals(from fileURL: URL) throws -> [GoalData] {
        try parse(fileURL: fileURL, as: [GoalData].self)
    }

    /// Parse PersonalValues from JSON file
    public func parsePersonalValues(from fileURL: URL) throws -> [PersonalValueData] {
        try parse(fileURL: fileURL, as: [PersonalValueData].self)
    }

    /// Parse TimePeriods from JSON file
    public func parseTimePeriods(from fileURL: URL) throws -> [TimePeriodData] {
        try parse(fileURL: fileURL, as: [TimePeriodData].self)
    }
}
