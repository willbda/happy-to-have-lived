//
// ActionRepository_v3.swift
// Written by Claude Code on 2025-11-16
//
// PURPOSE:
// Repository for Action entities using canonical ActionData type.
// Most complex repository - handles measurements (1:many) and goal contributions (1:many).
//
// DESIGN DECISIONS:
// - Extends BaseRepository<ActionData> (no separate export type)
// - Uses JSON aggregation for measurements + goal contributions
// - Relationship data: measurements[] and contributions[] via json_group_array
// - Inherits: error mapping, read/write wrappers, date filtering, pagination
// - Adds entity-specific: relationship queries, aggregations, compound uniqueness checks
//
// COMPLEXITY vs OTHER REPOSITORIES:
// - Goal: 3 relationships (measures, values, term) - similar complexity
// - Action: 2 relationships (measurements, contributions) - similar complexity
// - PersonalValue: 1 relationship (aligned goals) - simpler
// - TimePeriod: 0 relationships (simple 1:1 JOIN) - simplest
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Action entities with measurements and goal contributions
///
/// **Architecture Pattern**:
/// ```
/// ActionRepository_v3 → BaseRepository<ActionData> → Repository protocol
///                    ↓
///         JSONAggregationStrategy (for measurements + contributions)
/// ```
///
/// **What BaseRepository Provides**:
/// - ✅ Error mapping (mapDatabaseError with customization)
/// - ✅ Read/write wrappers with automatic error handling
/// - ✅ Date filtering helpers (DateFilter)
/// - ✅ Pagination (fetch(limit:offset:), fetchRecent(limit:))
///
/// **What This Repository Adds**:
/// - Entity-specific queries (fetchByGoal, fetchByDateRange)
/// - Aggregations (totalByMeasure, countByGoal)
/// - Compound uniqueness checks (exists(title:on:) - title + date)
/// - JSON aggregation assembly (measurements + contributions → ActionData)
///
public final class ActionRepository_v3: BaseRepository<ActionData> {

    // MARK: - Required Overrides

    /// Fetch all actions with measurements and goal contributions
    ///
    /// **Implementation Strategy**: JSON Aggregation
    /// - Single SQL query with 2 nested SELECT subqueries for relationships
    /// - Avoids N+1 problem (single database round trip)
    /// - Returns ActionData (canonical type)
    ///
    /// **SQL Pattern** (from ActionRepository.swift:284-344):
    /// ```sql
    /// SELECT a.*,
    ///   COALESCE((SELECT json_group_array(json_object(...)) FROM measuredActions JOIN measures), '[]'),
    ///   COALESCE((SELECT json_group_array(json_object(...)) FROM actionGoalContributions JOIN goals), '[]')
    /// FROM actions a
    /// ORDER BY logTime DESC
    /// ```
    public override func fetchAll() async throws -> [ActionData] {
        try await read { db in
            let sql = """
                SELECT
                    a.id as actionId,
                    a.title as actionTitle,
                    a.detailedDescription as actionDetailedDescription,
                    a.freeformNotes as actionFreeformNotes,
                    a.logTime as actionLogTime,
                    a.durationMinutes as actionDurationMinutes,
                    a.startTime as actionStartTime,

                    -- Measurements JSON array (all measurements for this action)
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'measuredActionId', ma.id,
                                    'value', ma.value,
                                    'createdAt', ma.createdAt,
                                    'measureId', m.id,
                                    'measureTitle', m.title,
                                    'measureUnit', m.unit,
                                    'measureType', m.measureType
                                )
                            )
                            FROM measuredActions ma
                            JOIN measures m ON ma.measureId = m.id
                            WHERE ma.actionId = a.id
                        ),
                        '[]'
                    ) as measurementsJson,

                    -- Contributions JSON array (all goals this action contributes to)
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'contributionId', agc.id,
                                    'contributionAmount', agc.contributionAmount,
                                    'measureId', agc.measureId,
                                    'createdAt', agc.createdAt,
                                    'goalId', g.id,
                                    'goalTitle', e.title
                                )
                            )
                            FROM actionGoalContributions agc
                            JOIN goals g ON agc.goalId = g.id
                            JOIN expectations e ON g.expectationId = e.id
                            WHERE agc.actionId = a.id
                        ),
                        '[]'
                    ) as contributionsJson

                FROM actions a
                ORDER BY a.logTime DESC
                """

            let rows = try ActionQueryRow.fetchAll(db, sql: sql)
            return try rows.map { try self.assembleActionData(from: $0) }
        }
    }

    /// Check if action exists by ID
    ///
    /// **Implementation**: Simple SELECT query with LIMIT
    /// Uses inherited `read` wrapper for automatic error mapping.
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            let sql = "SELECT 1 FROM actions WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Fetch actions with optional date filtering (for export)
    ///
    /// **Implementation**: Same as fetchAll() + WHERE clause on logTime
    /// Uses DateFilter helper from ExportSupport for consistent date filtering.
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [ActionData] {
        try await read { db in
            let dateFilter = DateFilter(startDate: startDate, endDate: endDate)
            let (whereClause, arguments) = dateFilter.buildWhereClause(dateColumn: "a.logTime")

            let sql = """
                SELECT
                    a.id as actionId,
                    a.title as actionTitle,
                    a.detailedDescription as actionDetailedDescription,
                    a.freeformNotes as actionFreeformNotes,
                    a.logTime as actionLogTime,
                    a.durationMinutes as actionDurationMinutes,
                    a.startTime as actionStartTime,

                    -- Measurements JSON array
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'measuredActionId', ma.id,
                                    'value', ma.value,
                                    'createdAt', ma.createdAt,
                                    'measureId', m.id,
                                    'measureTitle', m.title,
                                    'measureUnit', m.unit,
                                    'measureType', m.measureType
                                )
                            )
                            FROM measuredActions ma
                            JOIN measures m ON ma.measureId = m.id
                            WHERE ma.actionId = a.id
                        ),
                        '[]'
                    ) as measurementsJson,

                    -- Contributions JSON array
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'contributionId', agc.id,
                                    'contributionAmount', agc.contributionAmount,
                                    'measureId', agc.measureId,
                                    'createdAt', agc.createdAt,
                                    'goalId', g.id,
                                    'goalTitle', e.title
                                )
                            )
                            FROM actionGoalContributions agc
                            JOIN goals g ON agc.goalId = g.id
                            JOIN expectations e ON g.expectationId = e.id
                            WHERE agc.actionId = a.id
                        ),
                        '[]'
                    ) as contributionsJson

                FROM actions a
                \(whereClause)
                ORDER BY a.logTime DESC
                """

            let rows = try ActionQueryRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return try rows.map { try self.assembleActionData(from: $0) }
        }
    }

    // MARK: - Entity-Specific Queries

    /// Fetch actions within a date range
    ///
    /// **Use Case**: "Show all actions from last week" or term-based filtering
    /// **Implementation**: Uses DateFilter helper for consistent date handling
    public func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [ActionData] {
        try await fetchForExport(from: range.lowerBound, to: range.upperBound)
    }

    /// Fetch actions contributing to a specific goal
    ///
    /// **Use Case**: "What actions contributed to this goal?"
    /// **Implementation**: WHERE EXISTS with subquery on actionGoalContributions
    public func fetchByGoal(_ goalId: UUID) async throws -> [ActionData] {
        try await read { db in
            let sql = """
                SELECT
                    a.id as actionId,
                    a.title as actionTitle,
                    a.detailedDescription as actionDetailedDescription,
                    a.freeformNotes as actionFreeformNotes,
                    a.logTime as actionLogTime,
                    a.durationMinutes as actionDurationMinutes,
                    a.startTime as actionStartTime,

                    -- Measurements JSON array
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'measuredActionId', ma.id,
                                    'value', ma.value,
                                    'createdAt', ma.createdAt,
                                    'measureId', m.id,
                                    'measureTitle', m.title,
                                    'measureUnit', m.unit,
                                    'measureType', m.measureType
                                )
                            )
                            FROM measuredActions ma
                            JOIN measures m ON ma.measureId = m.id
                            WHERE ma.actionId = a.id
                        ),
                        '[]'
                    ) as measurementsJson,

                    -- Contributions JSON array
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'contributionId', agc.id,
                                    'contributionAmount', agc.contributionAmount,
                                    'measureId', agc.measureId,
                                    'createdAt', agc.createdAt,
                                    'goalId', g.id,
                                    'goalTitle', e.title
                                )
                            )
                            FROM actionGoalContributions agc
                            JOIN goals g ON agc.goalId = g.id
                            JOIN expectations e ON g.expectationId = e.id
                            WHERE agc.actionId = a.id
                        ),
                        '[]'
                    ) as contributionsJson

                FROM actions a
                WHERE EXISTS (
                    SELECT 1 FROM actionGoalContributions agc2
                    WHERE agc2.actionId = a.id AND agc2.goalId = ?
                )
                ORDER BY a.logTime DESC
                """

            let rows = try ActionQueryRow.fetchAll(db, sql: sql, arguments: [goalId])
            return try rows.map { try self.assembleActionData(from: $0) }
        }
    }

    /// Fetch recent actions with limit
    ///
    /// **Use Case**: Dashboard "Last 10 actions" widget
    /// **Implementation**: ORDER BY logTime DESC LIMIT ?
    public func fetchRecentActions(limit: Int) async throws -> [ActionData] {
        try await read { db in
            let sql = """
                SELECT
                    a.id as actionId,
                    a.title as actionTitle,
                    a.detailedDescription as actionDetailedDescription,
                    a.freeformNotes as actionFreeformNotes,
                    a.logTime as actionLogTime,
                    a.durationMinutes as actionDurationMinutes,
                    a.startTime as actionStartTime,

                    -- Measurements JSON array
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'measuredActionId', ma.id,
                                    'value', ma.value,
                                    'createdAt', ma.createdAt,
                                    'measureId', m.id,
                                    'measureTitle', m.title,
                                    'measureUnit', m.unit,
                                    'measureType', m.measureType
                                )
                            )
                            FROM measuredActions ma
                            JOIN measures m ON ma.measureId = m.id
                            WHERE ma.actionId = a.id
                        ),
                        '[]'
                    ) as measurementsJson,

                    -- Contributions JSON array
                    COALESCE(
                        (
                            SELECT json_group_array(
                                json_object(
                                    'contributionId', agc.id,
                                    'contributionAmount', agc.contributionAmount,
                                    'measureId', agc.measureId,
                                    'createdAt', agc.createdAt,
                                    'goalId', g.id,
                                    'goalTitle', e.title
                                )
                            )
                            FROM actionGoalContributions agc
                            JOIN goals g ON agc.goalId = g.id
                            JOIN expectations e ON g.expectationId = e.id
                            WHERE agc.actionId = a.id
                        ),
                        '[]'
                    ) as contributionsJson

                FROM actions a
                ORDER BY a.logTime DESC
                LIMIT ?
                """

            let rows = try ActionQueryRow.fetchAll(db, sql: sql, arguments: [limit])
            return try rows.map { try self.assembleActionData(from: $0) }
        }
    }

    /// Check if action exists by title and date (compound uniqueness)
    ///
    /// **Use Case**: Prevent duplicate "Morning run on 2025-11-16"
    /// **Implementation**: WHERE title = ? AND logTime BETWEEN startOfDay AND endOfDay
    ///
    /// **Note**: More complex than PersonalValue's simple title check.
    /// Actions can have same title on different days.
    public func exists(title: String, on date: Date) async throws -> Bool {
        try await read { db in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return false
            }

            let sql = """
                SELECT 1 FROM actions
                WHERE title = ? AND logTime >= ? AND logTime < ?
                LIMIT 1
                """

            return try Row.fetchOne(db, sql: sql, arguments: [title, startOfDay, endOfDay]) != nil
        }
    }

    // MARK: - Aggregation Queries

    /// Calculate total value for a measure within a date range
    ///
    /// **Use Case**: "How many miles did I run this month?"
    /// **Implementation**: SUM(value) WHERE measureId = ? AND logTime BETWEEN ? AND ?
    public func totalByMeasure(_ measureId: UUID, in range: ClosedRange<Date>) async throws -> Double {
        try await read { db in
            let sql = """
                SELECT COALESCE(SUM(ma.value), 0.0) as total
                FROM measuredActions ma
                INNER JOIN actions a ON ma.actionId = a.id
                WHERE ma.measureId = ?
                  AND a.logTime BETWEEN ? AND ?
                """

            return try Double.fetchOne(db, sql: sql, arguments: [measureId, range.lowerBound, range.upperBound]) ?? 0.0
        }
    }

    /// Count actions contributing to a specific goal
    ///
    /// **Use Case**: "How many actions contributed to this goal?"
    /// **Implementation**: COUNT(DISTINCT actionId) WHERE goalId = ?
    public func countByGoal(_ goalId: UUID) async throws -> Int {
        try await read { db in
            let sql = """
                SELECT COUNT(DISTINCT actionId)
                FROM actionGoalContributions
                WHERE goalId = ?
                """

            return try Int.fetchOne(db, sql: sql, arguments: [goalId]) ?? 0
        }
    }

    // MARK: - Error Mapping Override

    /// Map database errors to user-friendly validation errors
    ///
    /// **Action-specific mappings**:
    /// - FOREIGN KEY on measureId → invalidMeasure
    /// - FOREIGN KEY on goalId → invalidGoal
    /// - NOT NULL on title/logTime → missingRequiredField
    public override func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return .databaseConstraint(error.localizedDescription)
        }

        let message = dbError.message ?? ""

        // Check constraint type
        switch dbError.resultCode {
        case .SQLITE_CONSTRAINT_FOREIGNKEY:
            if message.contains("measureId") {
                return .invalidMeasure("Measure not found")
            }
            if message.contains("goalId") {
                return .invalidGoal("Goal not found")
            }
            return .foreignKeyViolation("Referenced entity not found")

        case .SQLITE_CONSTRAINT_UNIQUE:
            return .duplicateRecord("This action already exists")

        case .SQLITE_CONSTRAINT_NOTNULL:
            if message.contains("title") {
                return .missingRequiredField("Action title is required")
            }
            if message.contains("logTime") {
                return .missingRequiredField("Action log time is required")
            }
            return .missingRequiredField(message)

        case .SQLITE_CONSTRAINT:
            return .databaseConstraint(message)

        case .SQLITE_BUSY, .SQLITE_LOCKED:
            return .databaseConstraint("Database is temporarily unavailable. Please try again.")

        default:
            return .databaseConstraint(dbError.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// Assemble ActionData from JSON query row
    ///
    /// **Pattern**: Parse 2 JSON arrays (measurements + contributions)
    ///
    /// **Process** (from ActionRepository.swift:416-482):
    /// 1. Parse action fields (UUID, dates)
    /// 2. Decode measurementsJson → [MeasurementJsonRow]
    /// 3. Transform to [ActionData.Measurement]
    /// 4. Decode contributionsJson → [ContributionJsonRow]
    /// 5. Transform to [ActionData.Contribution]
    /// 6. Assemble ActionData
    ///
    /// - Parameter row: ActionQueryRow with action fields + 2 JSON arrays
    /// - Returns: Assembled ActionData
    /// - Throws: ValidationError if JSON parsing or UUID conversion fails
    private func assembleActionData(from row: ActionQueryRow) throws -> ActionData {
        let decoder = JSONDecoder()

        // Parse action ID
        guard let actionUUID = UUID(uuidString: row.actionId) else {
            throw ValidationError.databaseConstraint("Invalid action ID: \(row.actionId)")
        }

        // Parse measurements JSON
        guard let measurementsData = row.measurementsJson.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid measurements JSON encoding")
        }

        let measurementsJson = try decoder.decode([MeasurementJsonRow].self, from: measurementsData)

        let measurements: [ActionData.Measurement] = try measurementsJson.map { m in
            guard let measuredActionUUID = UUID(uuidString: m.measuredActionId),
                  let measureUUID = UUID(uuidString: m.measureId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in measurement for action \(row.actionId)")
            }

            return ActionData.Measurement(
                id: measuredActionUUID,
                measureId: measureUUID,
                measureTitle: m.measureTitle,
                measureUnit: m.measureUnit,
                measureType: m.measureType,
                value: m.value,
                createdAt: parseDate(m.createdAt) ?? Date()
            )
        }

        // Parse contributions JSON
        guard let contributionsData = row.contributionsJson.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid contributions JSON encoding")
        }

        let contributionsJson = try decoder.decode([ContributionJsonRow].self, from: contributionsData)

        let contributions: [ActionData.Contribution] = try contributionsJson.map { c in
            guard let contributionUUID = UUID(uuidString: c.contributionId),
                  let goalUUID = UUID(uuidString: c.goalId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in contribution for action \(row.actionId)")
            }

            let measureUUID: UUID? = if let mid = c.measureId {
                UUID(uuidString: mid)
            } else {
                nil
            }

            return ActionData.Contribution(
                id: contributionUUID,
                goalId: goalUUID,
                goalTitle: c.goalTitle,
                contributionAmount: c.contributionAmount,
                measureId: measureUUID,
                createdAt: parseDate(c.createdAt) ?? Date()
            )
        }

        return ActionData(
            id: actionUUID,
            title: row.actionTitle,
            detailedDescription: row.actionDetailedDescription,
            freeformNotes: row.actionFreeformNotes,
            logTime: parseDate(row.actionLogTime) ?? Date(),
            durationMinutes: row.actionDurationMinutes,
            startTime: parseDate(row.actionStartTime),
            measurements: measurements,
            contributions: contributions
        )
    }

    // MARK: - Query Row Types
    //
    // NOTE: parseDate() inherited from BaseRepository (no override needed)

    /// Result row from JSON aggregation query
    ///
    /// **Pattern**: Matches SQL SELECT columns (ActionRepository.swift:361-374)
    /// **Usage**: Intermediate struct for SQL → ActionData transformation
    private struct ActionQueryRow: Decodable, FetchableRecord, Sendable {
        // Action fields
        let actionId: String
        let actionTitle: String?
        let actionDetailedDescription: String?
        let actionFreeformNotes: String?
        let actionLogTime: String
        let actionDurationMinutes: Double?
        let actionStartTime: String?

        // JSON arrays (decoded as strings, parsed manually)
        let measurementsJson: String
        let contributionsJson: String
    }

    /// Decoded measurement from JSON array
    ///
    /// **Pattern**: Matches json_object() in SQL (ActionRepository.swift:379-392)
    private struct MeasurementJsonRow: Decodable, Sendable {
        let measuredActionId: String
        let value: Double
        let createdAt: String
        let measureId: String
        let measureTitle: String?
        let measureUnit: String
        let measureType: String
    }

    /// Decoded contribution from JSON array
    ///
    /// **Pattern**: Matches json_object() in SQL (ActionRepository.swift:395-402)
    private struct ContributionJsonRow: Decodable, Sendable {
        let contributionId: String
        let contributionAmount: Double?
        let measureId: String?
        let createdAt: String
        let goalId: String
        let goalTitle: String?  // From JOIN with expectations table
    }
}

// MARK: - Sendable Conformance

// ActionRepository_v3 is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - Safe to pass between actor boundaries
extension ActionRepository_v3: @unchecked Sendable {}

// =============================================================================
// IMPLEMENTATION NOTES
// =============================================================================
//
// COMPLEXITY RANKING:
// 1. ActionRepository_v3 (this file) - 2 relationships, complex JSON parsing
// 2. GoalRepository_v3 - 3 relationships, most complex JSON parsing
// 3. PersonalValueRepository_v3 - 1 relationship, simple UUID array
// 4. TimePeriodRepository_v3 - 0 relationships, simple 1:1 JOIN
//
// JSON AGGREGATION PATTERN:
// Actions have 2 JSON aggregation subqueries:
// 1. measurementsJson - measuredActions JOIN measures (measurement details)
// 2. contributionsJson - actionGoalContributions JOIN goals JOIN expectations (goal titles)
//
// This is simpler than Goals (3 relationships) but more complex than PersonalValues (1).
//
// ASSEMBLY COMPLEXITY:
// - Parse 2 JSON arrays (not 3 like Goals)
// - Each array contains nested objects (not just UUIDs like PersonalValues)
// - Date parsing needed for logTime, startTime, createdAt fields
// - UUID parsing needed for all ID fields
//
// ERROR MAPPING:
// Action-specific constraints:
// - FOREIGN KEY on measureId (measurement must exist)
// - FOREIGN KEY on goalId (goal must exist for contribution)
// - NOT NULL on title, logTime
// - No compound UNIQUE constraints (duplicate detection is time-based)
//
// QUERY PATTERNS:
// - fetchAll(): Base JSON aggregation query
// - fetchByGoal(): Add WHERE EXISTS subquery
// - fetchByDateRange(): Add WHERE logTime BETWEEN ? AND ?
// - totalByMeasure(): Aggregation without JSON (simple SUM)
// - countByGoal(): Aggregation without JSON (simple COUNT)
//
// =============================================================================
