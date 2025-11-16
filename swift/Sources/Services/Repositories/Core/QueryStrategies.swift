//
// QueryStrategies.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Define query strategy protocols for different repository patterns.
// Allows repositories to declare their query approach while maintaining flexibility.
//
// PATTERNS:
// - JSONAggregationStrategy: Complex 1:many relationships via json_group_array
// - SQLMacroStrategy: Simple queries using #sql macro
// - QueryBuilderStrategy: Simple JOINs using SQLiteData query builders
//

import Foundation
import Models
import SQLiteData
import GRDB

// MARK: - JSON Aggregation Strategy

/// Strategy for repositories using JSON aggregation for complex relationships
///
/// PATTERN: Single-query strategy using SQLite's json_group_array() to fetch
/// canonical data types with all their relationships in one database round-trip.
///
/// USAGE: ActionRepository (returns ActionData),
///        GoalRepository (returns GoalData)
///
/// EXAMPLE:
/// ```swift
/// final class ActionRepository_v3: BaseRepository<ActionData>, JSONAggregationStrategy {
///     typealias QueryRow = ActionQueryRow
///
///     var baseQuerySQL: String { "SELECT ..." }
///
///     func assembleData(from row: QueryRow) throws -> ActionData {
///         // Parse JSON and return ActionData
///     }
/// }
/// ```
public protocol JSONAggregationStrategy {
    /// The canonical data type being assembled (ActionData, GoalData, etc.)
    associatedtype DataType: Codable & Sendable

    /// The row type returned by the JSON aggregation query
    associatedtype QueryRow: Decodable, FetchableRecord, Sendable

    /// Base SQL query with JSON aggregation columns
    ///
    /// Should include json_group_array() for relationships:
    /// ```sql
    /// SELECT
    ///     e.id,
    ///     e.title,
    ///     COALESCE(
    ///         (SELECT json_group_array(json_object(...))
    ///          FROM related_table WHERE ...),
    ///         '[]'
    ///     ) as relatedJson
    /// FROM entity e
    /// ```
    var baseQuerySQL: String { get }

    /// Assemble canonical data type from the query row
    ///
    /// Parses JSON columns and constructs the canonical data type:
    /// ```swift
    /// func assembleData(from row: QueryRow) throws -> DataType {
    ///     // Parse JSON arrays from row
    ///     let measurements = try JSONAggregationHelper.decodeJSONArray(
    ///         row.measurementsJson,
    ///         as: MeasurementJsonRow.self,
    ///         context: "measurements"
    ///     )
    ///     // Return canonical data type (ActionData, GoalData, etc.)
    ///     return DataType(...)
    /// }
    /// ```
    func assembleData(from row: QueryRow) throws -> DataType
}

/// Helper utilities for JSON aggregation strategy
public struct JSONAggregationHelper {
    /// Decode a JSON string into an array of objects
    ///
    /// Provides consistent error handling and date decoding strategy.
    ///
    /// - Parameters:
    ///   - jsonString: The JSON string from database
    ///   - type: The array element type to decode
    ///   - context: Description for error messages (e.g., "measurements")
    /// - Returns: Decoded array of objects
    /// - Throws: ValidationError if parsing fails
    public static func decodeJSONArray<T: Decodable>(
        _ jsonString: String,
        as type: T.Type,
        context: String
    ) throws -> [T] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid UTF-8 in \(context) JSON")
        }

        let decoder = JSONDecoder()
        // Use ISO8601 date format for consistency with SQLite
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([T].self, from: data)
        } catch {
            throw ValidationError.databaseConstraint(
                "Failed to parse \(context): \(error.localizedDescription)"
            )
        }
    }

    /// Parse UUID from string with validation
    ///
    /// - Parameters:
    ///   - uuidString: The UUID string to parse
    ///   - context: Description for error messages
    /// - Returns: Parsed UUID
    /// - Throws: ValidationError if invalid UUID
    public static func parseUUID(_ uuidString: String, context: String) throws -> UUID {
        guard let uuid = UUID(uuidString: uuidString) else {
            throw ValidationError.databaseConstraint("Invalid \(context) UUID: \(uuidString)")
        }
        return uuid
    }

    /// Parse optional UUID from string
    ///
    /// - Parameters:
    ///   - uuidString: The optional UUID string to parse
    ///   - context: Description for error messages
    /// - Returns: Parsed UUID or nil
    /// - Throws: ValidationError if non-nil but invalid
    public static func parseOptionalUUID(_ uuidString: String?, context: String) throws -> UUID? {
        guard let uuidString = uuidString else { return nil }
        return try parseUUID(uuidString, context: context)
    }
}

// MARK: - SQL Macro Strategy

/// Strategy for repositories using SQLiteData's #sql macro
///
/// PATTERN: Direct SQL queries with compile-time type safety.
/// Best for simple canonical data types without complex nested relationships.
///
/// USAGE: PersonalValueRepository (returns PersonalValueData)
///
/// EXAMPLE:
/// ```swift
/// final class PersonalValueRepository_v3: BaseRepository<PersonalValueData>, SQLMacroStrategy {
///     override func fetchAll() async throws -> [PersonalValueData] {
///         try await read { db in
///             // Query returns PersonalValueData directly
///             // Or query PersonalValue and transform to PersonalValueData
///         }
///     }
/// }
/// ```
public protocol SQLMacroStrategy {
    /// The canonical data type being queried (PersonalValueData, etc.)
    associatedtype DataType: Codable & Sendable

    // No additional requirements - repositories using this strategy
    // implement queries directly with #sql macro
}

// MARK: - Query Builder Strategy

/// Strategy for repositories using SQLiteData query builders
///
/// PATTERN: Fluent query builder API for simple JOINs.
/// Good middle ground between raw SQL and complex aggregations.
///
/// USAGE: TimePeriodRepository (GoalTerm + TimePeriod simple JOIN)
///
/// NOTE: This strategy has limitations as SQLiteData doesn't provide
/// full query builder extensions for all types. Repositories may need
/// to fall back to raw SQL for some operations.
///
/// EXAMPLE:
/// ```swift
/// extension TimePeriodRepository: QueryBuilderStrategy {
///     func fetchAll() async throws -> [TermWithPeriod] {
///         try await read { db in
///             // Note: This would work if SQLiteData provided extensions
///             let results = try GoalTerm.all
///                 .order { $0.termNumber.desc() }
///                 .join(TimePeriod.all) { $0.timePeriodId.eq($1.id) }
///                 .fetchAll(db)
///         }
///     }
/// }
/// ```
public protocol QueryBuilderStrategy {
    /// The primary entity type
    associatedtype PrimaryEntity

    /// The entity being joined
    associatedtype JoinedEntity

    // No additional requirements - repositories using this strategy
    // implement queries with SQLiteData's query builder API
}

// MARK: - Hybrid Strategy

/// Strategy for repositories that mix patterns based on query complexity
///
/// PATTERN: Use the simplest appropriate pattern for each query.
/// Allows optimization per operation rather than forcing one pattern.
///
/// USAGE: Future repositories that need flexibility
public protocol HybridQueryStrategy: JSONAggregationStrategy, SQLMacroStrategy, QueryBuilderStrategy {
    // Combines all strategies - repository chooses per method
}

// MARK: - FetchKeyRequest Pattern

/// Common FetchKeyRequest implementations for reuse across repositories
///
/// These can be used by any repository regardless of query strategy.
public struct CommonFetchRequests {
    /// Check if an entity exists by ID
    public struct ExistsByIdRequest: FetchKeyRequest {
        public typealias Value = Bool

        let id: UUID
        let tableName: String

        public init(id: UUID, tableName: String) {
            self.id = id
            self.tableName = tableName
        }

        public func fetch(_ db: Database) throws -> Bool {
            let sql = "SELECT 1 FROM \(tableName) WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Check if an entity exists by title (case-insensitive)
    public struct ExistsByTitleRequest: FetchKeyRequest {
        public typealias Value = Bool

        let title: String
        let tableName: String
        let titleColumn: String

        public init(title: String, tableName: String, titleColumn: String = "title") {
            self.title = title
            self.tableName = tableName
            self.titleColumn = titleColumn
        }

        public func fetch(_ db: Database) throws -> Bool {
            let sql = """
                SELECT 1 FROM \(tableName)
                WHERE LOWER(\(titleColumn)) = LOWER(?)
                LIMIT 1
                """
            return try Row.fetchOne(db, sql: sql, arguments: [title]) != nil
        }
    }

    // NOTE: CountRequest commented out - not compatible with Swift 6 Sendable requirements
    // and not used in v3 repositories (which use direct SQL instead of FetchKeyRequest pattern)
    //
    // /// Count entities in a table with optional filter
    // public struct CountRequest: FetchKeyRequest {
    //     public typealias Value = Int
    //
    //     let tableName: String
    //     let whereClause: String?
    //     let arguments: [any DatabaseValueConvertible]
    //
    //     public init(tableName: String, whereClause: String? = nil, arguments: [any DatabaseValueConvertible] = []) {
    //         self.tableName = tableName
    //         self.whereClause = whereClause
    //         self.arguments = arguments
    //     }
    //
    //     public func fetch(_ db: Database) throws -> Int {
    //         var sql = "SELECT COUNT(*) FROM \(tableName)"
    //         if let whereClause = whereClause {
    //             sql += " WHERE \(whereClause)"
    //         }
    //         return try Int.fetchOne(db, sql: sql, arguments: StatementArguments(arguments)) ?? 0
    //     }
    // }
}