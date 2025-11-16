//
// PersonalValueRepository.swift
// Written by Claude Code on 2025-11-08
// Refactored to #sql pattern on 2025-11-10
// Refactored to canonical PersonalValueData on 2025-11-16
//
// PURPOSE:
// Read coordinator for PersonalValue entities - centralizes query logic.
// Complements PersonalValueCoordinator (writes) by handling all read operations.
//
// RESPONSIBILITIES:
// 1. Read operations - fetchAll(), fetchByLevel(), fetchById(), fetchByGoal()
// 2. Existence checks - existsByTitle(), exists()
// 3. Error mapping - DatabaseError → ValidationError
//
// QUERY PATTERN:
// Uses SQLiteData's #sql macro for all queries.
// - Type-safe SQL with compile-time table/column checking
// - Direct SQL for clarity and performance
// - FetchKeyRequest pattern for complex multi-value queries
//
// CANONICAL PATTERN:
// - fetchAll() returns PersonalValueData (not PersonalValue)
// - fetchAllLegacy() deprecated but available for backward compatibility
// - PersonalValueData serves both display and export needs
//

import Foundation
import Models
import SQLiteData
import GRDB  // For StatementArguments, DatabaseValueConvertible, FetchableRecord

// MARK: - Export Types

/// Denormalized personal value record for CSV/JSON export
///
/// EXPORT PATTERN:
/// - Flat structure (no nested objects) for CSV compatibility
/// - All PersonalValue fields included
/// - Computed statistics from database (alignedGoalCount)
/// - Date filtering on logTime field
///
/// USAGE:
/// ```swift
/// let exports = try await repository.fetchForExport(
///     from: Date().addingTimeInterval(-30 * 86400),  // Last 30 days
///     to: Date()
/// )
/// ```
public struct PersonalValueExport: Codable, Sendable {
    // Core identity
    public let id: String  // UUID as string for CSV
    public let title: String
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let logTime: String  // ISO8601 formatted

    // Value-specific fields
    public let priority: Int
    public let valueLevel: String  // ValueLevel.rawValue
    public let lifeDomain: String?
    public let alignmentGuidance: String?

    // Computed statistics
    public let alignedGoalCount: Int  // Number of goals aligned with this value
}

// REMOVED @MainActor: Repository performs database queries which are I/O
// operations that should run in background. Database reads should not block
// the main thread. ViewModels will await results on main actor as needed.
//
// SENDABLE: Conforms to Sendable for Swift 6 strict concurrency.
// Safe because:
// - Only immutable property (private let database)
// - All methods are async (thread-safe by nature)
// - Can be safely passed from @MainActor ViewModels to background tasks
public final class PersonalValueRepository: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Read Operations

    /// Fetch all personal values ordered by priority (highest priority first) - LEGACY
    ///
    /// - Warning: Deprecated. Use fetchAll() which returns canonical PersonalValueData.
    @available(*, deprecated, renamed: "fetchAll", message: "Use fetchAll() which returns canonical PersonalValueData. Transform with .asValue if needed.")
    public func fetchAllLegacy() async throws -> [PersonalValue] {
        do {
            return try await database.read { db in
                try #sql(
                    """
                    SELECT \(PersonalValue.columns)
                    FROM \(PersonalValue.self)
                    ORDER BY \(PersonalValue.priority) DESC
                    """,
                    as: PersonalValue.self
                ).fetchAll(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch all personal values as canonical PersonalValueData (for both display and export)
    ///
    /// **CANONICAL PATTERN**: Returns PersonalValueData that's already Codable
    /// **Usage**:
    /// - Export: Use directly (already Codable)
    /// - Display: Use PersonalValueData directly or transform with `.asValue` if needed
    /// - ViewModels: Store PersonalValueData, not PersonalValue
    ///
    /// **Query Strategy**:
    /// - Simple LEFT JOIN with goalRelevances for aligned goal IDs
    /// - GROUP BY + json_group_array for denormalization
    /// - No N+1 queries (single query fetches all data)
    ///
    /// - Parameters:
    ///   - startDate: Optional filter for values created or modified after this date
    ///   - endDate: Optional filter for values created or modified before this date
    public func fetchAll(
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [PersonalValueData] {
        do {
            return try await database.read { db in
                try FetchAllPersonalValueDataRequest(
                    startDate: startDate,
                    endDate: endDate
                ).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch values of a specific level
    public func fetchByLevel(_ level: ValueLevel) async throws -> [PersonalValue] {
        do {
            return try await database.read { db in
                try #sql(
                    """
                    SELECT \(PersonalValue.columns)
                    FROM \(PersonalValue.self)
                    WHERE \(PersonalValue.valueLevel) = \(bind: level)
                    ORDER BY \(PersonalValue.priority) DESC
                    """,
                    as: PersonalValue.self
                ).fetchAll(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch single value by ID
    public func fetchById(_ id: UUID) async throws -> PersonalValue? {
        do {
            return try await database.read { db in
                try #sql(
                    """
                    SELECT \(PersonalValue.columns)
                    FROM \(PersonalValue.self)
                    WHERE \(PersonalValue.id) = \(bind: id)
                    """,
                    as: PersonalValue.self
                ).fetchOne(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Fetch values aligned with a specific goal
    public func fetchByGoal(_ goalId: UUID) async throws -> [PersonalValue] {
        do {
            return try await database.read { db in
                try #sql(
                    """
                    SELECT \(PersonalValue.columns)
                    FROM \(PersonalValue.self)
                    INNER JOIN \(GoalRelevance.self) ON \(PersonalValue.id) = \(GoalRelevance.valueId)
                    WHERE \(GoalRelevance.goalId) = \(bind: goalId)
                    ORDER BY \(PersonalValue.priority) DESC
                    """,
                    as: PersonalValue.self
                ).fetchAll(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    // MARK: - Export Operations (DEPRECATED)

    /// Fetch denormalized export-ready data with optional date filtering - DEPRECATED
    ///
    /// - Warning: Deprecated. Use fetchAll() which returns canonical PersonalValueData.
    ///            PersonalValueData is already Codable and serves both display and export.
    ///
    /// Returns flat PersonalValueExport records optimized for CSV/JSON serialization.
    /// Includes aligned goal count computed from goalRelevances table.
    ///
    /// - Parameters:
    ///   - startDate: Optional filter for values created on or after this date
    ///   - endDate: Optional filter for values created on or before this date
    /// - Returns: Array of export-ready PersonalValueExport records
    ///
    /// QUERY STRATEGY:
    /// - Uses LEFT JOIN to include values with zero aligned goals
    /// - COUNT(goalRelevances.id) computes aligned goal count
    /// - Date filtering on logTime field (when value was created)
    /// - Results ordered by priority (highest first) for readability
    ///
    /// EXAMPLE:
    /// ```swift
    /// // OLD (deprecated):
    /// let exports = try await repository.fetchForExport()
    ///
    /// // NEW (use instead):
    /// let values = try await repository.fetchAll()
    /// ```
    @available(*, deprecated, message: "Use fetchAll() which returns canonical PersonalValueData. PersonalValueData is already Codable for export.")
    public func fetchForExport(
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [PersonalValueExport] {
        do {
            return try await database.read { db in
                // Query for PersonalValue with aligned goal count
                struct ExportRow: Decodable, FetchableRecord {
                    let id: UUID
                    let title: String?
                    let detailedDescription: String?
                    let freeformNotes: String?
                    let logTime: Date
                    let priority: Int?
                    let valueLevel: ValueLevel
                    let lifeDomain: String?
                    let alignmentGuidance: String?
                    let alignedGoalCount: Int
                }

                // Build SQL with optional date filters
                var sql = """
                    SELECT
                        pv.id,
                        pv.title,
                        pv.detailedDescription,
                        pv.freeformNotes,
                        pv.logTime,
                        pv.priority,
                        pv.valueLevel,
                        pv.lifeDomain,
                        pv.alignmentGuidance,
                        COUNT(gr.id) as alignedGoalCount
                    FROM personalValues pv
                    LEFT JOIN goalRelevances gr ON pv.id = gr.valueId
                    """

                var arguments: [any DatabaseValueConvertible] = []

                // Add date filters if provided
                var whereClauses: [String] = []
                if let startDate = startDate {
                    whereClauses.append("pv.logTime >= ?")
                    arguments.append(startDate)
                }
                if let endDate = endDate {
                    whereClauses.append("pv.logTime <= ?")
                    arguments.append(endDate)
                }

                if !whereClauses.isEmpty {
                    sql += " WHERE " + whereClauses.joined(separator: " AND ")
                }

                sql += """

                    GROUP BY pv.id
                    ORDER BY pv.priority ASC
                    """

                // Execute query with bound parameters
                let rows = try ExportRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

                // Transform to export format
                let iso8601 = ISO8601DateFormatter()
                iso8601.formatOptions = [.withInternetDateTime]

                return rows.map { row in
                    PersonalValueExport(
                        id: row.id.uuidString,
                        title: row.title ?? "",
                        detailedDescription: row.detailedDescription,
                        freeformNotes: row.freeformNotes,
                        logTime: iso8601.string(from: row.logTime),
                        priority: row.priority ?? row.valueLevel.defaultPriority,
                        valueLevel: row.valueLevel.rawValue,
                        lifeDomain: row.lifeDomain,
                        alignmentGuidance: row.alignmentGuidance,
                        alignedGoalCount: row.alignedGoalCount
                    )
                }
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    // MARK: - Existence Checks

    /// Check if a value with this title already exists (case-insensitive)
    public func existsByTitle(_ title: String) async throws -> Bool {
        do {
            return try await database.read { db in
                try ExistsByTitleRequest(title: title).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Check if a value exists by ID
    public func exists(_ id: UUID) async throws -> Bool {
        do {
            return try await database.read { db in
                try ExistsByIdRequest(id: id).fetch(db)
            }
        } catch {
            throw mapDatabaseError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return .databaseConstraint(error.localizedDescription)
        }

        switch dbError.resultCode {
        case .SQLITE_CONSTRAINT_UNIQUE:
            return .duplicateRecord("A value with this title already exists")
        case .SQLITE_CONSTRAINT_NOTNULL:
            let message = dbError.message ?? "Required field is missing"
            return .missingRequiredField(message)
        case .SQLITE_CONSTRAINT_FOREIGNKEY:
            return .foreignKeyViolation("Referenced record no longer exists")
        case .SQLITE_CONSTRAINT:
            let message = dbError.message ?? "Database constraint violated"
            return .databaseConstraint(message)
        default:
            return .databaseConstraint(dbError.localizedDescription)
        }
    }
}

// MARK: - Fetch Requests

/// Fetch all personal values with aligned goal IDs
///
/// **QUERY PATTERN**: Single query with LEFT JOIN and json_group_array
/// **Performance**: O(n) where n = number of values (no N+1 problem)
///
/// SQL Strategy:
/// ```sql
/// SELECT pv.*, COALESCE(json_group_array(gr.goalId), '[]') as alignedGoalIdsJson
/// FROM personalValues pv
/// LEFT JOIN goalRelevances gr ON pv.id = gr.valueId
/// GROUP BY pv.id
/// ORDER BY pv.priority ASC
/// ```
private struct FetchAllPersonalValueDataRequest: FetchKeyRequest {
    typealias Value = [PersonalValueData]

    let startDate: Date?
    let endDate: Date?

    func fetch(_ db: Database) throws -> [PersonalValueData] {
        // Use raw SQL with json_group_array for efficient aggregation
        var sql = """
            SELECT
                pv.id,
                pv.title,
                pv.detailedDescription,
                pv.freeformNotes,
                pv.logTime,
                pv.priority,
                pv.valueLevel,
                pv.lifeDomain,
                pv.alignmentGuidance,
                COALESCE(
                    (SELECT json_group_array(gr.goalId)
                     FROM goalRelevances gr
                     WHERE gr.valueId = pv.id),
                    '[]'
                ) as alignedGoalIdsJson
            FROM personalValues pv
            """

        var arguments: [any DatabaseValueConvertible] = []

        // Add date filters if provided
        var whereClauses: [String] = []
        if let startDate = startDate {
            whereClauses.append("pv.logTime >= ?")
            arguments.append(startDate)
        }
        if let endDate = endDate {
            whereClauses.append("pv.logTime <= ?")
            arguments.append(endDate)
        }

        if !whereClauses.isEmpty {
            sql += " WHERE " + whereClauses.joined(separator: " AND ")
        }

        sql += "\nORDER BY pv.priority ASC"

        // Define intermediate row type for decoding
        struct ValueRow: Decodable, FetchableRecord {
            let id: UUID
            let title: String?
            let detailedDescription: String?
            let freeformNotes: String?
            let logTime: Date
            let priority: Int?
            let valueLevel: ValueLevel
            let lifeDomain: String?
            let alignmentGuidance: String?
            let alignedGoalIdsJson: String
        }

        // Execute query
        let rows = try ValueRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

        // Transform to PersonalValueData
        return try rows.map { row in
            // Parse JSON array of goal IDs
            let alignedGoalIds: [UUID]
            if let jsonData = row.alignedGoalIdsJson.data(using: .utf8),
               let uuidStrings = try? JSONDecoder().decode([String].self, from: jsonData) {
                alignedGoalIds = uuidStrings.compactMap { UUID(uuidString: $0) }
            } else {
                alignedGoalIds = []
            }

            return PersonalValueData(
                id: row.id,
                title: row.title ?? "",
                detailedDescription: row.detailedDescription,
                freeformNotes: row.freeformNotes,
                logTime: row.logTime,
                priority: row.priority ?? row.valueLevel.defaultPriority,
                valueLevel: row.valueLevel.rawValue,
                lifeDomain: row.lifeDomain,
                alignmentGuidance: row.alignmentGuidance,
                alignedGoalIds: alignedGoalIds
            )
        }
    }
}

/// Check if a title exists (case-insensitive)
private struct ExistsByTitleRequest: FetchKeyRequest {
    typealias Value = Bool
    let title: String

    func fetch(_ db: Database) throws -> Bool {
        let count = try #sql(
            """
            SELECT COUNT(*)
            FROM \(PersonalValue.self)
            WHERE LOWER(\(PersonalValue.title)) = LOWER(\(bind: title))
            """,
            as: Int.self
        ).fetchOne(db) ?? 0
        return count > 0
    }
}

/// Check if an ID exists
private struct ExistsByIdRequest: FetchKeyRequest {
    typealias Value = Bool
    let id: UUID

    func fetch(_ db: Database) throws -> Bool {
        let count = try #sql(
            """
            SELECT COUNT(*)
            FROM \(PersonalValue.self)
            WHERE \(PersonalValue.id) = \(bind: id)
            """,
            as: Int.self
        ).fetchOne(db) ?? 0
        return count > 0
    }
}

// MARK: - Implementation Notes

// WHY #sql MACRO?
//
// Benefits:
// 1. Type Safety - Compile-time checking of table/column names via \(Type.column)
// 2. SQL Clarity - Standard SQL is universally understood
// 3. Performance - Direct SQL execution
// 4. Power - Full SQL feature set (JOINs, CTEs, window functions)
// 5. Security - Automatic SQL injection protection with \(bind:)
//
// Pattern:
// - Simple queries: Direct #sql() calls in repository methods
// - Complex queries: FetchKeyRequest structs for multi-value results
// - All parameters use \(bind: value) for safe SQL injection prevention
// - Error mapping ensures user-friendly messages (DatabaseError → ValidationError)

// WHY FetchKeyRequest FOR EXISTENCE CHECKS?
//
// While simple, existence checks benefit from FetchKeyRequest pattern:
// - Encapsulates COUNT query logic
// - Makes intent explicit (returns Bool, not Int)
// - Easy to test in isolation
// - Reusable if needed elsewhere
// - Follows SQLiteData patterns
