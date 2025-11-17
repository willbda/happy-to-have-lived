//
// PersonalValueRepository.swift
// Written by Claude Code on 2025-11-16
//
// PURPOSE:
// Repository for PersonalValue entities using canonical PersonalValueData type.
// Simpler than Action/Goal - fewer relationships, straightforward query pattern.
//
// DESIGN DECISIONS:
// - Extends BaseRepository<PersonalValueData> (no separate export type)
// - Uses JSON aggregation for aligned goal IDs (1:many via goalRelevances)
// - Relationship data: alignedGoalIds array collected via json_group_array
// - Inherits: error mapping, read/write wrappers, date filtering, pagination
// - Adds entity-specific: title uniqueness check, priority/level filtering
//
// INTERACTION WITH CORE:
// - BaseRepository: Provides read/write wrappers, error mapping, pagination helpers
// - QueryStrategies: Uses JSONAggregationStrategy (even though simple, for consistency)
// - ExportSupport: Date filtering via DateFilter helper
// - RepositoryProtocols: Conforms to Repository protocol (single DataType)
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing PersonalValue entities
///
/// **Architecture Pattern**:
/// ```
/// PersonalValueRepository → BaseRepository<PersonalValueData> → Repository protocol
///                         ↓
///                  JSON Aggregation (aligned goal IDs)
/// ```
///
/// **Simplicity vs Action/Goal**:
/// - PersonalValue has ONE relationship (aligned goals via goalRelevances)
/// - No nested structures like measurements/contributions
/// - Still uses JSON aggregation for consistency with other repositories
///
/// **What BaseRepository Provides**:
/// - ✅ Error mapping (mapDatabaseError)
/// - ✅ Read/write wrappers with automatic error handling
/// - ✅ Date filtering helpers (DateFilter)
/// - ✅ Pagination (fetch(limit:offset:), fetchRecent(limit:))
///
/// **What This Repository Adds**:
/// - Title uniqueness checks (exists(title:))
/// - Priority-based filtering (fetchByPriority)
/// - Value level filtering (fetchByValueLevel)
/// - Goal alignment queries (fetchAlignedWith)
/// - Life domain filtering (fetchByLifeDomain)
///
public final class PersonalValueRepository: BaseRepository<PersonalValueData> {

    // MARK: - Required Overrides

    /// Fetch all personal values with aligned goal IDs
    ///
    /// **Implementation Strategy**: JSON aggregation with subquery
    /// - Uses COALESCE + json_group_array for aligned goal IDs
    /// - Single query (no N+1 problem)
    /// - Returns PersonalValueData (canonical type)
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// SELECT pv.*,
    ///   COALESCE(
    ///     (SELECT json_group_array(goalId) FROM goalRelevances WHERE valueId = pv.id),
    ///     '[]'
    ///   ) as alignedGoalIdsJson
    /// FROM personalValues pv
    /// ORDER BY priority ASC
    /// ```
    public override func fetchAll() async throws -> [PersonalValueData] {
        try await read { db in
            let sql = """
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
                ORDER BY pv.priority ASC
                """

            let rows = try ValueQueryRow.fetchAll(db, sql: sql)
            return try rows.map { try self.assembleValueData(from: $0) }
        }
    }

    /// Check if personal value exists by ID
    ///
    /// **Implementation**: Simple COUNT query
    /// Uses inherited `read` wrapper for automatic error mapping.
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            let sql = "SELECT 1 FROM personalValues WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Fetch values with optional date filtering (for export)
    ///
    /// **Implementation**: Same as fetchAll() + WHERE clause on logTime
    /// Uses DateFilter helper from ExportSupport for consistent date filtering.
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [PersonalValueData] {
        try await read { db in
            let dateFilter = DateFilter(startDate: startDate, endDate: endDate)
            let (whereClause, arguments) = dateFilter.buildWhereClause(dateColumn: "pv.logTime")

            let sql = """
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
                \(whereClause)
                ORDER BY pv.priority ASC
                """

            let rows = try ValueQueryRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return try rows.map { try self.assembleValueData(from: $0) }
        }
    }

    // MARK: - Entity-Specific Queries

    /// Check if value with title already exists (case-insensitive)
    ///
    /// **Use Case**: Prevent duplicate "Family" values in validation
    /// **Implementation**: SELECT COUNT WHERE LOWER(title) = LOWER(?)
    ///
    /// **Note**: Simpler than Action's compound check (title+date).
    /// Values only need title uniqueness.
    public func exists(title: String) async throws -> Bool {
        try await read { db in
            let sql = """
                SELECT 1 FROM personalValues
                WHERE LOWER(title) = LOWER(?)
                LIMIT 1
                """
            return try Row.fetchOne(db, sql: sql, arguments: [title]) != nil
        }
    }

    /// Fetch values by priority threshold
    ///
    /// **Use Case**: "Show all values with priority >= 8" for high-priority filtering
    /// **Implementation**: WHERE priority >= ? ORDER BY priority DESC
    public func fetchByPriority(minimumPriority: Int) async throws -> [PersonalValueData] {
        try await read { db in
            let sql = """
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
                WHERE pv.priority >= ?
                ORDER BY pv.priority ASC
                """

            let rows = try ValueQueryRow.fetchAll(db, sql: sql, arguments: [minimumPriority])
            return try rows.map { try self.assembleValueData(from: $0) }
        }
    }

    /// Fetch values by value level
    ///
    /// **Use Case**: "Show only highest_order values" or "Show all life_area values"
    /// **Implementation**: WHERE valueLevel = ?
    ///
    /// **Value Levels**: general, major, highest_order, life_area
    public func fetchByValueLevel(_ level: String) async throws -> [PersonalValueData] {
        try await read { db in
            let sql = """
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
                WHERE pv.valueLevel = ?
                ORDER BY pv.priority ASC
                """

            let rows = try ValueQueryRow.fetchAll(db, sql: sql, arguments: [level])
            return try rows.map { try self.assembleValueData(from: $0) }
        }
    }

    /// Fetch values aligned with a specific goal
    ///
    /// **Use Case**: "What values does this goal serve?" (inverse of alignedGoalIds)
    /// **Implementation**: INNER JOIN with goalRelevances WHERE goalId = ?
    ///
    /// **Note**: This is the inverse query of PersonalValueData.alignedGoalIds.
    /// While PersonalValueData stores "which goals align with this value",
    /// this query answers "which values align with this goal".
    public func fetchAlignedWith(goalId: UUID) async throws -> [PersonalValueData] {
        try await read { db in
            let sql = """
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
                INNER JOIN goalRelevances gr ON pv.id = gr.valueId
                WHERE gr.goalId = ?
                ORDER BY pv.priority ASC
                """

            let rows = try ValueQueryRow.fetchAll(db, sql: sql, arguments: [goalId])
            return try rows.map { try self.assembleValueData(from: $0) }
        }
    }

    /// Fetch values by life domain
    ///
    /// **Use Case**: "Show all health-related values" for domain-specific filtering
    /// **Implementation**: WHERE lifeDomain = ?
    ///
    /// **Note**: lifeDomain is optional (can be NULL), so this only returns values with explicit domain
    public func fetchByLifeDomain(_ domain: String) async throws -> [PersonalValueData] {
        try await read { db in
            let sql = """
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
                WHERE pv.lifeDomain = ?
                ORDER BY pv.priority ASC
                """

            let rows = try ValueQueryRow.fetchAll(db, sql: sql, arguments: [domain])
            return try rows.map { try self.assembleValueData(from: $0) }
        }
    }

    // MARK: - Error Mapping Override

    /// Map database errors to user-friendly validation errors
    ///
    /// **PersonalValue-specific mappings**:
    /// - CHECK constraint on valueLevel → custom validation message
    /// - All other constraints handled by BaseRepository
    ///
    /// **PATTERN**: Override only value-specific error cases, delegate rest to BaseRepository
    public override func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return super.mapDatabaseError(error)  // Delegate non-DB errors to base
        }

        // Handle value-specific CHECK constraints (valueLevel enum validation)
        if dbError.resultCode == .SQLITE_CONSTRAINT_CHECK {
            if dbError.message?.contains("valueLevel") == true {
                return .databaseConstraint("Invalid value level (must be: general, major, highest_order, or life_area)")
            }
        }

        // All other errors handled by base implementation
        // (UNIQUE, NOTNULL, FOREIGNKEY, BUSY, LOCKED, etc.)
        return super.mapDatabaseError(error)
    }

    // MARK: - Private Helpers

    /// Assemble PersonalValueData from query row
    ///
    /// **Pattern**: Parse alignedGoalIdsJson array from JSON aggregation
    ///
    /// **Simpler than GoalData**: Only one relationship to assemble (aligned goal IDs)
    /// No nested structures like measurements or contributions.
    ///
    /// - Parameter row: ValueQueryRow with all PersonalValue fields + alignedGoalIdsJson
    /// - Returns: Assembled PersonalValueData
    /// - Throws: ValidationError if JSON parsing fails
    private func assembleValueData(from row: ValueQueryRow) throws -> PersonalValueData {
        // Parse aligned goal IDs from JSON array
        let alignedGoalIds: [UUID]
        if let jsonData = row.alignedGoalIdsJson.data(using: .utf8) {
            do {
                let uuidStrings = try JSONDecoder().decode([String].self, from: jsonData)
                alignedGoalIds = uuidStrings.compactMap { UUID(uuidString: $0) }
            } catch {
                throw ValidationError.databaseConstraint("Failed to parse aligned goal IDs: \(error.localizedDescription)")
            }
        } else {
            alignedGoalIds = []
        }

        return PersonalValueData(
            id: row.id,
            title: row.title,
            detailedDescription: row.detailedDescription,
            freeformNotes: row.freeformNotes,
            logTime: row.logTime,
            priority: row.priority,
            valueLevel: row.valueLevel,
            lifeDomain: row.lifeDomain,
            alignmentGuidance: row.alignmentGuidance,
            alignedGoalIds: alignedGoalIds
        )
    }

    /// Query row structure matching SQL SELECT columns
    ///
    /// **Fields**:
    /// - PersonalValue columns (id, title, detailedDescription, etc.)
    /// - alignedGoalIdsJson: JSON array of UUID strings from json_group_array
    ///
    /// **Usage**: Intermediate struct for SQL → PersonalValueData transformation
    private struct ValueQueryRow: Decodable, FetchableRecord, Sendable {
        // PersonalValue fields (from personalValues table)
        let id: UUID
        let title: String
        let detailedDescription: String?
        let freeformNotes: String?
        let logTime: Date
        let priority: Int
        let valueLevel: String
        let lifeDomain: String?
        let alignmentGuidance: String?

        // Relationship data (JSON aggregated from goalRelevances)
        let alignedGoalIdsJson: String  // JSON array of UUID strings: ["uuid1", "uuid2", ...]
    }
}

// MARK: - Sendable Conformance

// PersonalValueRepository_v3 is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - Safe to pass between actor boundaries
extension PersonalValueRepository: @unchecked Sendable {}

// =============================================================================
// IMPLEMENTATION NOTES
// =============================================================================
//
// SIMPLICITY vs GOAL/ACTION:
// PersonalValue has the simplest relationship graph:
// - 1:many with goalRelevances (just goal IDs, no nested data)
// - No measurement data (like Actions)
// - No term assignments (like Goals)
// - No contribution tracking
//
// This makes the query pattern straightforward:
// 1. SELECT personalValue fields
// 2. Use json_group_array subquery for aligned goal IDs
// 3. Parse JSON array (just UUIDs, not nested objects)
// 4. Assemble PersonalValueData
//
// QUERY STRATEGY:
// Uses JSON aggregation (like Goal/Action) for consistency, even though simple.
// Alternative would be #sql macro with separate query for alignments, but
// JSON aggregation provides:
// - Single-query efficiency (no N+1)
// - Consistency with other repositories
// - Simpler code (no manual relationship assembly)
//
// ERROR MAPPING:
// PersonalValue has fewer constraint types than Goal/Action:
// - UNIQUE on title only (no compound constraints)
// - NOT NULL on title/priority/valueLevel
// - CHECK constraint on valueLevel enum
// - No complex foreign key cascades
//
// =============================================================================
