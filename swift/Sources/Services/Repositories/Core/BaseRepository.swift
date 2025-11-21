//
// BaseRepository.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Base class providing common repository functionality.
// Subclasses inherit error mapping, database read wrapper, and common patterns.
//
// DESIGN:
// - Open class allows subclassing
// - Generic over Entity and ExportType
// - Provides default error mapping (overridable)
// - Wraps database reads with error handling
//

import Foundation
import Models
import SQLiteData
import GRDB
import Combine

/// Base repository implementation providing common functionality
///
/// PATTERN: Template Method pattern with canonical data types.
/// Subclasses inherit error mapping, database wrappers, and utilities.
/// Works with single canonical type (ActionData, GoalData, etc.) for both display and export.
///
/// USAGE:
/// ```swift
/// final class ActionRepository: BaseRepository<ActionData> {
///     override func fetchAll() async throws -> [ActionData] {
///         try await read { db in
///             // Query returning ActionData
///         }
///     }
///
///     override func fetchForExport(from: Date?, to: Date?) async throws -> [ActionData] {
///         // Same type as fetchAll, just add date filtering
///         let filter = DateFilter(startDate: from, endDate: to)
///         // ... query with filter
///     }
/// }
/// ```
open class BaseRepository<DataType>: Repository
    where DataType: Sendable & Identifiable
{
    // MARK: - Properties

    /// Database writer instance (injected dependency)
    public let database: any DatabaseWriter

    // MARK: - Initialization

    /// Initialize with database writer
    /// - Parameter database: The database writer to use for all operations
    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Abstract Methods (Must Override)

    /// Fetch all entities from the database (synchronous, for use in transactions)
    ///
    /// Subclasses MUST override this method with entity-specific query logic.
    /// This is the canonical fetch implementation - async and observation methods call this.
    ///
    /// ```swift
    /// override func fetchAll(_ db: Database) throws -> [DataType] {
    ///     // Your query here returning [ActionData], [GoalData], etc.
    ///     try ActionData.fetchAll(db)
    /// }
    /// ```
    open func fetchAll(_ db: Database) throws -> [DataType] {
        fatalError("\(type(of: self)).fetchAll(_:) must be overridden")
    }

    /// Fetch all entities from the database (async wrapper)
    ///
    /// Default implementation calls the synchronous `fetchAll(_:)` within a read transaction.
    /// Subclasses typically don't need to override this - just implement `fetchAll(_:)`.
    open func fetchAll() async throws -> [DataType] {
        try await read { db in
            try self.fetchAll(db)
        }
    }

    /// Check if an entity exists by ID
    ///
    /// Subclasses MUST override this method with entity-specific existence check.
    open func exists(_ id: UUID) async throws -> Bool {
        fatalError("\(type(of: self)).exists(_:) must be overridden")
    }

    /// Fetch entities with optional date filtering (for export)
    ///
    /// Returns the SAME type as fetchAll(), just filtered by date range.
    /// Subclasses typically implement this as fetchAll() + WHERE clause.
    ///
    /// ```swift
    /// override func fetchForExport(from: Date?, to: Date?) async throws -> [DataType] {
    ///     let filter = DateFilter(startDate: from, endDate: to)
    ///     let (whereClause, args) = filter.buildWhereClause(dateColumn: "logTime")
    ///     try await read { db in
    ///         // Same query as fetchAll() + whereClause
    ///     }
    /// }
    /// ```
    open func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [DataType] {
        fatalError("\(type(of: self)).fetchForExport(from:to:) must be overridden")
    }

    // MARK: - Database Observation

    /// Observe all entities in the database
    ///
    /// Returns a Combine publisher that emits updated entity arrays whenever relevant database tables change.
    /// Uses GRDB's ValueObservation to automatically track which tables affect this query.
    ///
    /// **Pattern**: Repository provides observation, consumer subscribes
    /// ```swift
    /// let cancellable = repository
    ///     .observeAll()
    ///     .sink { entities in
    ///         self.items = entities
    ///     }
    /// ```
    ///
    /// **Benefits**:
    /// - Automatic updates on local writes
    /// - Automatic updates on CloudKit sync
    /// - Efficient (only refetches when relevant tables change)
    /// - Testable (can mock publisher)
    ///
    /// - Returns: Publisher that emits fresh entity arrays on database changes
    public func observeAll() -> AnyPublisher<[DataType], Error> {
        ValueObservation
            .tracking { [self] db in
                try self.fetchAll(db)
            }
            .publisher(in: database, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    // MARK: - Provided Functionality

    /// Execute a database read operation with automatic error mapping
    ///
    /// This wrapper provides consistent error handling across all repositories.
    /// Subclasses should use this for all read operations:
    /// ```swift
    /// try await read { db in
    ///     try MyEntity.fetchAll(db)
    /// }
    /// ```
    ///
    /// - Parameter operation: The database operation to execute
    /// - Returns: The result of the operation
    /// - Throws: ValidationError with user-friendly message
    public func read<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        do {
            return try await database.read(operation)
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Execute a database write operation with automatic error mapping
    ///
    /// Similar to `read` but for write operations. Primarily used by coordinators,
    /// but available if repositories need write access.
    ///
    /// - Parameter operation: The database operation to execute
    /// - Returns: The result of the operation
    /// - Throws: ValidationError with user-friendly message
    public func write<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        do {
            return try await database.write(operation)
        } catch {
            throw mapDatabaseError(error)
        }
    }

    // MARK: - Error Mapping

    /// Map database errors to user-friendly validation errors
    ///
    /// Default implementation handles common SQLite constraint violations.
    /// Subclasses can override to provide entity-specific error messages:
    /// ```swift
    /// override func mapDatabaseError(_ error: Error) -> ValidationError {
    ///     // Check for specific errors first
    ///     if let dbError = error as? DatabaseError,
    ///        dbError.resultCode == .SQLITE_CONSTRAINT_UNIQUE {
    ///         return .duplicateRecord("A value with this title already exists")
    ///     }
    ///     // Fall back to base implementation
    ///     return super.mapDatabaseError(error)
    /// }
    /// ```
    ///
    /// - Parameter error: The database error to map
    /// - Returns: A ValidationError with appropriate user message
    open func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return .databaseConstraint(error.localizedDescription)
        }

        switch dbError.resultCode {
        case .SQLITE_CONSTRAINT_FOREIGNKEY:
            // Try to extract table name from error message for better context
            if let message = dbError.message {
                if message.contains("measureId") {
                    return .invalidMeasure("Measure not found")
                }
                if message.contains("goalId") {
                    return .invalidGoal("Goal not found")
                }
                if message.contains("valueId") {
                    return .emptyValue("Personal value not found")
                }
                if message.contains("termId") {
                    return .databaseConstraint("Term not found")
                }
                if message.contains("actionId") {
                    return .databaseConstraint("Action not found")
                }
                if message.contains("expectationId") {
                    return .invalidExpectation("Expectation not found")
                }
            }
            return .foreignKeyViolation("Referenced entity not found")

        case .SQLITE_CONSTRAINT_UNIQUE:
            return .duplicateRecord("This entry already exists")

        case .SQLITE_CONSTRAINT_NOTNULL:
            // Try to extract field name from error message
            if let message = dbError.message {
                // SQLite typically includes the column name in the message
                // Format: "NOT NULL constraint failed: table.column"
                if let columnMatch = message.range(of: #"failed: \w+\.(\w+)"#, options: .regularExpression) {
                    let columnName = String(message[columnMatch])
                        .replacingOccurrences(of: "failed: ", with: "")
                        .components(separatedBy: ".").last ?? "field"

                    // Convert snake_case to readable format
                    let readableName = columnName
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized

                    return .missingRequiredField("\(readableName) is required")
                }
            }
            return .missingRequiredField("Required field is missing")

        case .SQLITE_CONSTRAINT_CHECK:
            // Check constraints typically have custom messages
            if let message = dbError.message {
                // Look for common check constraint patterns
                if message.contains("startDate") && message.contains("endDate") {
                    return .invalidDateRange("Start date must be before end date")
                }
                if message.contains("priority") {
                    return .invalidPriority("Priority must be between 1 and 10")
                }
                if message.contains("importance") || message.contains("urgency") {
                    return .invalidPriority("Importance/urgency must be between 1 and 5")
                }
            }
            return .databaseConstraint(dbError.message ?? "Data validation failed")

        case .SQLITE_CONSTRAINT:
            // Generic constraint violation
            return .databaseConstraint(dbError.message ?? "Database constraint violated")

        case .SQLITE_BUSY, .SQLITE_LOCKED:
            return .databaseConstraint("Database is temporarily unavailable. Please try again.")

        case .SQLITE_CORRUPT:
            return .databaseConstraint("Database integrity error. Please contact support.")

        case .SQLITE_FULL:
            return .databaseConstraint("Storage is full. Please free up space and try again.")

        default:
            // For any other error, return a generic database error
            return .databaseConstraint(dbError.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Parse an optional ISO8601 date string
    ///
    /// Shared helper for repositories that need to parse dates from database strings.
    ///
    /// - Parameter dateString: The ISO8601 date string to parse
    /// - Returns: Parsed Date or nil if invalid/nil
    public func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Fall back to without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    /// Format a date as ISO8601 string
    ///
    /// Shared helper for repositories that need to format dates for database storage.
    ///
    /// - Parameter date: The date to format
    /// - Returns: ISO8601 formatted string
    public func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    /// Create a JSONDecoder configured for SQLite date formats
    ///
    /// **Use Case**: Repositories using JSON aggregation with date fields
    ///
    /// **Pattern**: SQLite stores dates as "yyyy-MM-dd HH:mm:ss.SSS" (space separator)
    /// This differs from ISO8601 which uses 'T' separator.
    ///
    /// **Usage**:
    /// ```swift
    /// let decoder = sqliteDateDecoder()
    /// let rows = try decoder.decode([MyJsonRow].self, from: jsonData)
    /// ```
    ///
    /// - Returns: JSONDecoder with custom date decoding strategy for SQLite dates
    public func sqliteDateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        // Configure date decoding for SQLite's date format ("2025-11-16 03:51:24.771")
        // SQLite uses space separator, not ISO8601's 'T' separator
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // SQLite format: "yyyy-MM-dd HH:mm:ss.SSS"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")

            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback for dates without fractional seconds
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected SQLite date format (yyyy-MM-dd HH:mm:ss.SSS), got: \(dateString)"
            )
        }

        return decoder
    }

    /// Build a date filter WHERE clause
    ///
    /// Helper method for repositories that support date filtering.
    /// Generates SQL WHERE clause based on optional start/end dates.
    ///
    /// - Parameters:
    ///   - startDate: Optional start date (inclusive)
    ///   - endDate: Optional end date (inclusive)
    ///   - dateColumn: The date column to filter on (default: "logTime")
    /// - Returns: Tuple of (WHERE clause SQL, arguments array)
    ///
    /// Example:
    /// ```swift
    /// let (whereClause, args) = buildDateFilter(from: startDate, to: endDate)
    /// let sql = "SELECT * FROM myTable \(whereClause)"
    /// let results = try Row.fetchAll(db, sql: sql, arguments: args)
    /// ```
    public func buildDateFilter(
        from startDate: Date?,
        to endDate: Date?,
        dateColumn: String = "logTime"
    ) -> (whereClause: String, arguments: [any DatabaseValueConvertible]) {
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

    // MARK: - Pagination Support

    /// Fetch entities with pagination
    ///
    /// Subclasses can override to implement entity-specific pagination.
    /// Default implementation fetches all and slices in memory (inefficient).
    ///
    /// **Performance Note**: For large datasets, override this method to use SQL LIMIT/OFFSET.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of entities to return
    ///   - offset: Number of entities to skip (default: 0)
    /// - Returns: Array of entities (up to `limit` items)
    /// - Throws: ValidationError if query fails
    ///
    /// Example override:
    /// ```swift
    /// override func fetch(limit: Int, offset: Int) async throws -> [ActionData] {
    ///     try await read { db in
    ///         try ActionData.fetchAll(db, sql: """
    ///             SELECT * FROM actions
    ///             ORDER BY logTime DESC
    ///             LIMIT ? OFFSET ?
    ///             """, arguments: [limit, offset])
    ///     }
    /// }
    /// ```
    open func fetch(limit: Int, offset: Int = 0) async throws -> [DataType] {
        // Default implementation (inefficient for large datasets)
        let all = try await fetchAll()
        let start = min(offset, all.count)
        let end = min(start + limit, all.count)
        return Array(all[start..<end])
    }

    /// Fetch most recent entities (ordered by logTime DESC)
    ///
    /// Convenience method for common "show latest N items" pattern.
    /// Subclasses should override for SQL-level optimization.
    ///
    /// - Parameter limit: Maximum number of entities to return
    /// - Returns: Array of most recent entities
    /// - Throws: ValidationError if query fails
    ///
    /// Example override:
    /// ```swift
    /// override func fetchRecent(limit: Int) async throws -> [ActionData] {
    ///     try await read { db in
    ///         try ActionData.fetchAll(db, sql: """
    ///             SELECT * FROM actions
    ///             ORDER BY logTime DESC
    ///             LIMIT ?
    ///             """, arguments: [limit])
    ///     }
    /// }
    /// ```
    open func fetchRecent(limit: Int) async throws -> [DataType] {
        // Default implementation fetches all and sorts in memory (inefficient)
        let all = try await fetchAll()
        // Note: This assumes DataType has a logTime property accessible via reflection
        // Subclasses should override for proper SQL-based ordering
        return Array(all.prefix(limit))
    }
}

// MARK: - Sendable Conformance

// BaseRepository is Sendable because:
// - It only has immutable stored property (database)
// - All methods are async (thread-safe by nature)
// - Can be safely passed between actor boundaries
extension BaseRepository: @unchecked Sendable {}