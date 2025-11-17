//
// GoalRepository.swift
// Written by Claude Code on 2025-11-16
//
// PURPOSE:
// Repository for Goal entities using canonical GoalData type.
// Refactored from GoalRepository.swift to extend BaseRepository<GoalData>.
//
// DESIGN DECISIONS:
// - Extends BaseRepository<GoalData> (single generic parameter, no separate export type)
// - Reuses proven JSON aggregation SQL from GoalRepository.swift
// - Reuses assembleGoalData() function (lines 609-707 of original)
// - Eliminates FetchKeyRequest wrappers (direct async methods)
// - Inherits: error mapping, read/write wrappers, date filtering, pagination helpers
//
// MIGRATION FROM GOALREPOSITORY.SWIFT:
// - ✅ Proven SQL patterns preserved
// - ✅ JSON parsing logic unchanged
// - ❌ FetchKeyRequest wrappers eliminated (simpler)
// - ❌ Duplicate error mapping removed (uses BaseRepository)
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Goal entities using canonical GoalData
///
/// **Architecture**:
/// ```
/// GoalRepository → BaseRepository<GoalData> → Repository protocol
///                ↓
///       JSON Aggregation (3 relationships: measures + values + terms)
/// ```
///
/// **What BaseRepository Provides**:
/// - ✅ Error mapping (mapDatabaseError) - overridden for goal-specific messages
/// - ✅ Read/write wrappers with automatic error handling
/// - ✅ Date filtering helpers (buildDateFilter)
/// - ✅ Pagination base implementations (fetch/fetchRecent)
///
/// **What This Repository Adds**:
/// - Multi-table JSON aggregation (goals + expectations + 3 relationships)
/// - Entity-specific queries (active, byTerm, byValue, withProgress)
/// - Title uniqueness checks via expectations table
///
public final class GoalRepository: BaseRepository<GoalData> {

    // MARK: - Required Overrides (BaseRepository)

    /// Fetch all goals with full relationship graph using JSON aggregation
    ///
    /// **Pattern**: Single SQL query with nested json_group_array() subqueries
    /// **Performance**: O(1) queries regardless of goal count (was O(5n) before JSON aggregation)
    /// **Source**: Copied from GoalRepository.swift FetchAllGoalsRequest (lines 718-816)
    public override func fetchAll() async throws -> [GoalData] {
        try await read { db in
            let sql = """
            SELECT
                -- Goal fields (prefixed to avoid column name collisions)
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,

                -- Expectation fields
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,

                -- Measures as JSON array (SQLite does the grouping)
                COALESCE(
                    (
                        SELECT json_group_array(
                            json_object(
                                'expectationMeasureId', em.id,
                                'targetValue', em.targetValue,
                                'expectationMeasureFreeformNotes', em.freeformNotes,
                                'measureId', m.id,
                                'measureTitle', m.title,
                                'measureUnit', m.unit,
                                'measureType', m.measureType,
                                'measureDetailedDescription', m.detailedDescription,
                                'measureFreeformNotes', m.freeformNotes,
                                'measureLogTime', m.logTime,
                                'measureCanonicalUnit', m.canonicalUnit,
                                'measureConversionFactor', m.conversionFactor,
                                'expectationMeasureCreatedAt', em.createdAt
                            )
                        )
                        FROM expectationMeasures em
                        JOIN measures m ON em.measureId = m.id
                        WHERE em.expectationId = e.id
                    ),
                    '[]'
                ) as measuresJson,

                -- Values as JSON array (SQLite does the grouping)
                COALESCE(
                    (
                        SELECT json_group_array(
                            json_object(
                                'relevanceId', gr.id,
                                'alignmentStrength', gr.alignmentStrength,
                                'relevanceNotes', gr.relevanceNotes,
                                'valueId', v.id,
                                'valueTitle', v.title,
                                'valueDetailedDescription', v.detailedDescription,
                                'valueFreeformNotes', v.freeformNotes,
                                'valuePriority', v.priority,
                                'valueLevel', v.valueLevel,
                                'valueLifeDomain', v.lifeDomain,
                                'valueAlignmentGuidance', v.alignmentGuidance,
                                'valueLogTime', v.logTime,
                                'relevanceCreatedAt', gr.createdAt
                            )
                        )
                        FROM goalRelevances gr
                        JOIN personalValues v ON gr.valueId = v.id
                        WHERE gr.goalId = g.id
                    ),
                    '[]'
                ) as valuesJson,

                -- Term assignment (single object, most recent)
                COALESCE(
                    (
                        SELECT json_object(
                            'assignmentId', tga.id,
                            'termId', tga.termId,
                            'assignmentOrder', tga.assignmentOrder,
                            'createdAt', tga.createdAt
                        )
                        FROM termGoalAssignments tga
                        WHERE tga.goalId = g.id
                        ORDER BY tga.createdAt DESC
                        LIMIT 1
                    ),
                    'null'
                ) as termAssignmentJson

            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            ORDER BY g.targetDate ASC NULLS LAST
            """

            let rows = try GoalQueryRow.fetchAll(db, sql: sql)

            return try rows.map { row in
                try self.assembleGoalData(from: row)
            }
        }
    }

    /// Check if goal exists by ID
    ///
    /// **Implementation**: Simple SELECT with LIMIT 1 (fast index lookup)
    /// **Source**: Copied from GoalRepository.swift ExistsByIdRequest (lines 1145-1154)
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            let sql = "SELECT 1 FROM goals WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Fetch goals with optional date filtering (for export)
    ///
    /// **Date Filter Strategy**: Filter on expectation.logTime (when goal was created)
    /// **Note**: Goals table doesn't have logTime, but Expectation does
    /// **Source**: Adapted from GoalRepository.swift FetchFilteredGoalsRequest (lines 889-1016)
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [GoalData] {
        // Build WHERE clause using inherited helper
        let (whereClause, arguments) = buildDateFilter(
            from: startDate,
            to: endDate,
            dateColumn: "e.logTime"
        )

        return try await read { db in
            let sql = """
            SELECT
                -- Goal fields
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,

                -- Expectation fields
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,

                -- Measures as JSON array
                COALESCE(
                    (
                        SELECT json_group_array(
                            json_object(
                                'expectationMeasureId', em.id,
                                'targetValue', em.targetValue,
                                'expectationMeasureFreeformNotes', em.freeformNotes,
                                'measureId', m.id,
                                'measureTitle', m.title,
                                'measureUnit', m.unit,
                                'measureType', m.measureType,
                                'measureDetailedDescription', m.detailedDescription,
                                'measureFreeformNotes', m.freeformNotes,
                                'measureLogTime', m.logTime,
                                'measureCanonicalUnit', m.canonicalUnit,
                                'measureConversionFactor', m.conversionFactor,
                                'expectationMeasureCreatedAt', em.createdAt
                            )
                        )
                        FROM expectationMeasures em
                        JOIN measures m ON em.measureId = m.id
                        WHERE em.expectationId = e.id
                    ),
                    '[]'
                ) as measuresJson,

                -- Values as JSON array
                COALESCE(
                    (
                        SELECT json_group_array(
                            json_object(
                                'relevanceId', gr.id,
                                'alignmentStrength', gr.alignmentStrength,
                                'relevanceNotes', gr.relevanceNotes,
                                'valueId', v.id,
                                'valueTitle', v.title,
                                'valueDetailedDescription', v.detailedDescription,
                                'valueFreeformNotes', v.freeformNotes,
                                'valuePriority', v.priority,
                                'valueLevel', v.valueLevel,
                                'valueLifeDomain', v.lifeDomain,
                                'valueAlignmentGuidance', v.alignmentGuidance,
                                'valueLogTime', v.logTime,
                                'relevanceCreatedAt', gr.createdAt
                            )
                        )
                        FROM goalRelevances gr
                        JOIN personalValues v ON gr.valueId = v.id
                        WHERE gr.goalId = g.id
                    ),
                    '[]'
                ) as valuesJson,

                -- Term assignment (single object)
                COALESCE(
                    (
                        SELECT json_object(
                            'assignmentId', tga.id,
                            'termId', tga.termId,
                            'assignmentOrder', tga.assignmentOrder,
                            'createdAt', tga.createdAt
                        )
                        FROM termGoalAssignments tga
                        WHERE tga.goalId = g.id
                        ORDER BY tga.createdAt DESC
                        LIMIT 1
                    ),
                    'null'
                ) as termAssignmentJson

            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            \(whereClause)
            ORDER BY e.expectationImportance DESC, e.expectationUrgency DESC
            """

            let statement = try db.cachedStatement(sql: sql)
            let rows = try GoalQueryRow.fetchAll(statement, arguments: StatementArguments(arguments))

            return try rows.map { row in
                try self.assembleGoalData(from: row)
            }
        }
    }

    // MARK: - Pagination Overrides (SQL-level optimization)

    /// Fetch paginated goals with SQL LIMIT/OFFSET
    ///
    /// **Optimization**: Database-level pagination (not in-memory slicing)
    /// **Performance**: Avoids loading all goals into memory
    public override func fetch(limit: Int, offset: Int = 0) async throws -> [GoalData] {
        try await read { db in
            let sql = """
            SELECT
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'expectationMeasureId', em.id,
                        'targetValue', em.targetValue,
                        'expectationMeasureFreeformNotes', em.freeformNotes,
                        'measureId', m.id,
                        'measureTitle', m.title,
                        'measureUnit', m.unit,
                        'measureType', m.measureType,
                        'measureDetailedDescription', m.detailedDescription,
                        'measureFreeformNotes', m.freeformNotes,
                        'measureLogTime', m.logTime,
                        'measureCanonicalUnit', m.canonicalUnit,
                        'measureConversionFactor', m.conversionFactor,
                        'expectationMeasureCreatedAt', em.createdAt
                    )) FROM expectationMeasures em JOIN measures m ON em.measureId = m.id WHERE em.expectationId = e.id),
                    '[]'
                ) as measuresJson,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'relevanceId', gr.id,
                        'alignmentStrength', gr.alignmentStrength,
                        'relevanceNotes', gr.relevanceNotes,
                        'valueId', v.id,
                        'valueTitle', v.title,
                        'valueDetailedDescription', v.detailedDescription,
                        'valueFreeformNotes', v.freeformNotes,
                        'valuePriority', v.priority,
                        'valueLevel', v.valueLevel,
                        'valueLifeDomain', v.lifeDomain,
                        'valueAlignmentGuidance', v.alignmentGuidance,
                        'valueLogTime', v.logTime,
                        'relevanceCreatedAt', gr.createdAt
                    )) FROM goalRelevances gr JOIN personalValues v ON gr.valueId = v.id WHERE gr.goalId = g.id),
                    '[]'
                ) as valuesJson,
                COALESCE(
                    (SELECT json_object(
                        'assignmentId', tga.id,
                        'termId', tga.termId,
                        'assignmentOrder', tga.assignmentOrder,
                        'createdAt', tga.createdAt
                    ) FROM termGoalAssignments tga WHERE tga.goalId = g.id ORDER BY tga.createdAt DESC LIMIT 1),
                    'null'
                ) as termAssignmentJson
            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            ORDER BY g.targetDate ASC NULLS LAST
            LIMIT ? OFFSET ?
            """

            let rows = try GoalQueryRow.fetchAll(db, sql: sql, arguments: [limit, offset])
            return try rows.map { try self.assembleGoalData(from: $0) }
        }
    }

    /// Fetch most recent goals by creation time
    ///
    /// **Sort Order**: expectation.logTime DESC (when goal was created)
    /// **Note**: Not goal.startDate (when goal period begins)
    public override func fetchRecent(limit: Int) async throws -> [GoalData] {
        try await read { db in
            let sql = """
            SELECT
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'expectationMeasureId', em.id,
                        'targetValue', em.targetValue,
                        'expectationMeasureFreeformNotes', em.freeformNotes,
                        'measureId', m.id,
                        'measureTitle', m.title,
                        'measureUnit', m.unit,
                        'measureType', m.measureType,
                        'measureDetailedDescription', m.detailedDescription,
                        'measureFreeformNotes', m.freeformNotes,
                        'measureLogTime', m.logTime,
                        'measureCanonicalUnit', m.canonicalUnit,
                        'measureConversionFactor', m.conversionFactor,
                        'expectationMeasureCreatedAt', em.createdAt
                    )) FROM expectationMeasures em JOIN measures m ON em.measureId = m.id WHERE em.expectationId = e.id),
                    '[]'
                ) as measuresJson,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'relevanceId', gr.id,
                        'alignmentStrength', gr.alignmentStrength,
                        'relevanceNotes', gr.relevanceNotes,
                        'valueId', v.id,
                        'valueTitle', v.title,
                        'valueDetailedDescription', v.detailedDescription,
                        'valueFreeformNotes', v.freeformNotes,
                        'valuePriority', v.priority,
                        'valueLevel', v.valueLevel,
                        'valueLifeDomain', v.lifeDomain,
                        'valueAlignmentGuidance', v.alignmentGuidance,
                        'valueLogTime', v.logTime,
                        'relevanceCreatedAt', gr.createdAt
                    )) FROM goalRelevances gr JOIN personalValues v ON gr.valueId = v.id WHERE gr.goalId = g.id),
                    '[]'
                ) as valuesJson,
                COALESCE(
                    (SELECT json_object(
                        'assignmentId', tga.id,
                        'termId', tga.termId,
                        'assignmentOrder', tga.assignmentOrder,
                        'createdAt', tga.createdAt
                    ) FROM termGoalAssignments tga WHERE tga.goalId = g.id ORDER BY tga.createdAt DESC LIMIT 1),
                    'null'
                ) as termAssignmentJson
            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            ORDER BY e.logTime DESC
            LIMIT ?
            """

            let rows = try GoalQueryRow.fetchAll(db, sql: sql, arguments: [limit])
            return try rows.map { try self.assembleGoalData(from: $0) }
        }
    }

    // MARK: - Entity-Specific Queries

    /// Fetch active goals (no target date or target date in future)
    ///
    /// **Use Case**: QuickAdd sections, active goals dashboard
    /// **Source**: Adapted from GoalRepository.swift FetchActiveGoalsRequest (lines 819-887)
    public func fetchActiveGoals() async throws -> [GoalData] {
        try await read { db in
            let sql = """
            SELECT
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'expectationMeasureId', em.id,
                        'targetValue', em.targetValue,
                        'expectationMeasureFreeformNotes', em.freeformNotes,
                        'measureId', m.id,
                        'measureTitle', m.title,
                        'measureUnit', m.unit,
                        'measureType', m.measureType,
                        'measureDetailedDescription', m.detailedDescription,
                        'measureFreeformNotes', m.freeformNotes,
                        'measureLogTime', m.logTime,
                        'measureCanonicalUnit', m.canonicalUnit,
                        'measureConversionFactor', m.conversionFactor,
                        'expectationMeasureCreatedAt', em.createdAt
                    )) FROM expectationMeasures em JOIN measures m ON em.measureId = m.id WHERE em.expectationId = e.id),
                    '[]'
                ) as measuresJson,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'relevanceId', gr.id,
                        'alignmentStrength', gr.alignmentStrength,
                        'relevanceNotes', gr.relevanceNotes,
                        'valueId', v.id,
                        'valueTitle', v.title,
                        'valueDetailedDescription', v.detailedDescription,
                        'valueFreeformNotes', v.freeformNotes,
                        'valuePriority', v.priority,
                        'valueLevel', v.valueLevel,
                        'valueLifeDomain', v.lifeDomain,
                        'valueAlignmentGuidance', v.alignmentGuidance,
                        'valueLogTime', v.logTime,
                        'relevanceCreatedAt', gr.createdAt
                    )) FROM goalRelevances gr JOIN personalValues v ON gr.valueId = v.id WHERE gr.goalId = g.id),
                    '[]'
                ) as valuesJson,
                COALESCE(
                    (SELECT json_object(
                        'assignmentId', tga.id,
                        'termId', tga.termId,
                        'assignmentOrder', tga.assignmentOrder,
                        'createdAt', tga.createdAt
                    ) FROM termGoalAssignments tga WHERE tga.goalId = g.id ORDER BY tga.createdAt DESC LIMIT 1),
                    'null'
                ) as termAssignmentJson
            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            WHERE g.targetDate IS NULL OR g.targetDate >= date('now')
            ORDER BY g.targetDate ASC NULLS LAST
            """

            let rows = try GoalQueryRow.fetchAll(db, sql: sql)
            return try rows.map { try self.assembleGoalData(from: $0) }
        }
    }

    /// Fetch goals assigned to a specific term
    ///
    /// **Use Case**: Term planning views, goal term associations
    /// **Source**: Copied from GoalRepository.swift FetchGoalsByTermRequest (lines 1018-1124)
    public func fetchByTerm(_ termId: UUID) async throws -> [GoalData] {
        try await read { db in
            let sql = """
            SELECT
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'expectationMeasureId', em.id,
                        'targetValue', em.targetValue,
                        'expectationMeasureFreeformNotes', em.freeformNotes,
                        'measureId', m.id,
                        'measureTitle', m.title,
                        'measureUnit', m.unit,
                        'measureType', m.measureType,
                        'measureDetailedDescription', m.detailedDescription,
                        'measureFreeformNotes', m.freeformNotes,
                        'measureLogTime', m.logTime,
                        'measureCanonicalUnit', m.canonicalUnit,
                        'measureConversionFactor', m.conversionFactor,
                        'expectationMeasureCreatedAt', em.createdAt
                    )) FROM expectationMeasures em JOIN measures m ON em.measureId = m.id WHERE em.expectationId = e.id),
                    '[]'
                ) as measuresJson,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'relevanceId', gr.id,
                        'alignmentStrength', gr.alignmentStrength,
                        'relevanceNotes', gr.relevanceNotes,
                        'valueId', v.id,
                        'valueTitle', v.title,
                        'valueDetailedDescription', v.detailedDescription,
                        'valueFreeformNotes', v.freeformNotes,
                        'valuePriority', v.priority,
                        'valueLevel', v.valueLevel,
                        'valueLifeDomain', v.lifeDomain,
                        'valueAlignmentGuidance', v.alignmentGuidance,
                        'valueLogTime', v.logTime,
                        'relevanceCreatedAt', gr.createdAt
                    )) FROM goalRelevances gr JOIN personalValues v ON gr.valueId = v.id WHERE gr.goalId = g.id),
                    '[]'
                ) as valuesJson,
                COALESCE(
                    (SELECT json_object(
                        'assignmentId', tga.id,
                        'termId', tga.termId,
                        'assignmentOrder', tga.assignmentOrder,
                        'createdAt', tga.createdAt
                    ) FROM termGoalAssignments tga WHERE tga.goalId = g.id AND tga.termId = ? ORDER BY tga.createdAt DESC LIMIT 1),
                    'null'
                ) as termAssignmentJson
            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            INNER JOIN termGoalAssignments tga ON g.id = tga.goalId
            WHERE tga.termId = ?
            ORDER BY tga.assignmentOrder ASC NULLS LAST, g.targetDate ASC NULLS LAST
            """

            let rows = try GoalQueryRow.fetchAll(db, sql: sql, arguments: [termId, termId])
            return try rows.map { try self.assembleGoalData(from: $0) }
        }
    }

    /// Fetch goals aligned with a specific personal value
    ///
    /// **Use Case**: Value alignment analysis, "what goals serve this value"
    /// **Source**: Adapted from GoalRepository.swift fetchByValue (lines 235-266)
    /// **Change**: Returns GoalData (not Goal) with full relationship graph
    public func fetchByValue(_ valueId: UUID) async throws -> [GoalData] {
        try await read { db in
            let sql = """
            SELECT
                g.id as goalId,
                g.startDate as goalStartDate,
                g.targetDate as goalTargetDate,
                g.actionPlan as goalActionPlan,
                g.expectedTermLength as goalExpectedTermLength,
                e.id as expectationId,
                e.title as expectationTitle,
                e.detailedDescription as expectationDetailedDescription,
                e.freeformNotes as expectationFreeformNotes,
                e.logTime as expectationLogTime,
                e.expectationImportance,
                e.expectationUrgency,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'expectationMeasureId', em.id,
                        'targetValue', em.targetValue,
                        'expectationMeasureFreeformNotes', em.freeformNotes,
                        'measureId', m.id,
                        'measureTitle', m.title,
                        'measureUnit', m.unit,
                        'measureType', m.measureType,
                        'measureDetailedDescription', m.detailedDescription,
                        'measureFreeformNotes', m.freeformNotes,
                        'measureLogTime', m.logTime,
                        'measureCanonicalUnit', m.canonicalUnit,
                        'measureConversionFactor', m.conversionFactor,
                        'expectationMeasureCreatedAt', em.createdAt
                    )) FROM expectationMeasures em JOIN measures m ON em.measureId = m.id WHERE em.expectationId = e.id),
                    '[]'
                ) as measuresJson,
                COALESCE(
                    (SELECT json_group_array(json_object(
                        'relevanceId', gr.id,
                        'alignmentStrength', gr.alignmentStrength,
                        'relevanceNotes', gr.relevanceNotes,
                        'valueId', v.id,
                        'valueTitle', v.title,
                        'valueDetailedDescription', v.detailedDescription,
                        'valueFreeformNotes', v.freeformNotes,
                        'valuePriority', v.priority,
                        'valueLevel', v.valueLevel,
                        'valueLifeDomain', v.lifeDomain,
                        'valueAlignmentGuidance', v.alignmentGuidance,
                        'valueLogTime', v.logTime,
                        'relevanceCreatedAt', gr.createdAt
                    )) FROM goalRelevances gr JOIN personalValues v ON gr.valueId = v.id WHERE gr.goalId = g.id),
                    '[]'
                ) as valuesJson,
                COALESCE(
                    (SELECT json_object(
                        'assignmentId', tga.id,
                        'termId', tga.termId,
                        'assignmentOrder', tga.assignmentOrder,
                        'createdAt', tga.createdAt
                    ) FROM termGoalAssignments tga WHERE tga.goalId = g.id ORDER BY tga.createdAt DESC LIMIT 1),
                    'null'
                ) as termAssignmentJson
            FROM goals g
            JOIN expectations e ON g.expectationId = e.id
            WHERE g.id IN (
                SELECT goalId FROM goalRelevances WHERE valueId = ?
            )
            ORDER BY COALESCE(g.targetDate, g.startDate) ASC NULLS LAST
            """

            let rows = try GoalQueryRow.fetchAll(db, sql: sql, arguments: [valueId])
            return try rows.map { try self.assembleGoalData(from: $0) }
        }
    }

    // MARK: - Uniqueness Checks

    /// Check if a goal with this title already exists (case-insensitive)
    ///
    /// **Note**: Queries expectations table (goal titles stored there)
    /// **Source**: Copied from GoalRepository.swift ExistsByTitleRequest (lines 1127-1142)
    public func exists(title: String) async throws -> Bool {
        try await read { db in
            let sql = """
            SELECT COUNT(*)
            FROM expectations
            WHERE LOWER(title) = LOWER(?)
              AND expectationType = 'goal'
            """
            let count = try Int.fetchOne(db, sql: sql, arguments: [title]) ?? 0
            return count > 0
        }
    }

    // MARK: - Error Mapping Override

    /// Map database errors to goal-specific validation errors
    ///
    /// **Source**: Copied from GoalRepository.swift mapDatabaseError (lines 317-343)
    /// **Pattern**: Check for goal-specific foreign keys, fall back to super
    public override func mapDatabaseError(_ error: Error) -> ValidationError {
        guard let dbError = error as? DatabaseError else {
            return super.mapDatabaseError(error)
        }

        // Handle goal-specific foreign key violations
        if dbError.resultCode == .SQLITE_CONSTRAINT_FOREIGNKEY {
            if dbError.message?.contains("measureId") == true {
                return .invalidMeasure("Measure not found")
            }
            if dbError.message?.contains("valueId") == true {
                return .emptyValue("Personal value not found")
            }
            if dbError.message?.contains("termId") == true {
                return .databaseConstraint("Term not found")
            }
        }

        // All other errors handled by base implementation
        // (UNIQUE, NOTNULL, BUSY, LOCKED, etc.)
        return super.mapDatabaseError(error)
    }

    // MARK: - Private Helpers (JSON Assembly)

    /// Assemble GoalData from JSON query row
    ///
    /// **Source**: Copied from GoalRepository.swift assembleGoalData (lines 609-707)
    /// **Critical**: JSONDecoder date strategy must match SQLite format
    private func assembleGoalData(from row: GoalQueryRow) throws -> GoalData {
        // Use BaseRepository's SQLite date decoder for JSON aggregation
        let decoder = sqliteDateDecoder()

        // Parse goal and expectation IDs
        guard let goalUUID = UUID(uuidString: row.goalId) else {
            throw ValidationError.databaseConstraint("Invalid goal ID: \(row.goalId)")
        }

        guard let expectationUUID = UUID(uuidString: row.expectationId) else {
            throw ValidationError.databaseConstraint("Invalid expectation ID: \(row.expectationId)")
        }

        // Parse measures JSON
        guard let measuresData = row.measuresJson.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid UTF-8 in measures JSON for goal \(row.goalId)")
        }
        let measuresJson = try decoder.decode([MeasureJsonRow].self, from: measuresData)

        let measureTargets: [GoalData.MeasureTarget] = try measuresJson.map { m in
            guard let measureTargetUUID = UUID(uuidString: m.expectationMeasureId),
                  let measureUUID = UUID(uuidString: m.measureId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in measure for goal \(row.goalId)")
            }

            return GoalData.MeasureTarget(
                id: measureTargetUUID,
                measureId: measureUUID,
                measureTitle: m.measureTitle,
                measureUnit: m.measureUnit,
                measureType: m.measureType,
                targetValue: m.targetValue,
                freeformNotes: m.expectationMeasureFreeformNotes,
                createdAt: m.expectationMeasureCreatedAt
            )
        }

        // Parse values JSON
        guard let valuesData = row.valuesJson.data(using: .utf8) else {
            throw ValidationError.databaseConstraint("Invalid UTF-8 in values JSON for goal \(row.goalId)")
        }
        let valuesJson = try decoder.decode([ValueJsonRow].self, from: valuesData)

        let valueAlignments: [GoalData.ValueAlignment] = try valuesJson.map { v in
            guard let relevanceUUID = UUID(uuidString: v.relevanceId),
                  let valueUUID = UUID(uuidString: v.valueId) else {
                throw ValidationError.databaseConstraint("Invalid UUID in value for goal \(row.goalId)")
            }

            return GoalData.ValueAlignment(
                id: relevanceUUID,
                valueId: valueUUID,
                valueTitle: v.valueTitle,
                alignmentStrength: v.alignmentStrength,
                relevanceNotes: v.relevanceNotes,
                createdAt: v.relevanceCreatedAt
            )
        }

        // Parse term assignment JSON (optional single object)
        var termAssignment: GoalData.TermAssignment?
        if let termJson = row.termAssignmentJson,
           !termJson.isEmpty,
           termJson != "null",
           let termData = termJson.data(using: .utf8) {
            do {
                let termJsonRow = try decoder.decode(TermAssignmentJsonRow.self, from: termData)

                guard let assignmentUUID = UUID(uuidString: termJsonRow.assignmentId),
                      let termUUID = UUID(uuidString: termJsonRow.termId) else {
                    throw ValidationError.databaseConstraint("Invalid UUID in term assignment for goal \(row.goalId)")
                }

                termAssignment = GoalData.TermAssignment(
                    id: assignmentUUID,
                    termId: termUUID,
                    assignmentOrder: termJsonRow.assignmentOrder,
                    createdAt: termJsonRow.createdAt
                )
            } catch {
                // Term assignment is optional, log but don't fail
                print("Warning: Failed to parse term assignment for goal \(row.goalId): \(error)")
            }
        }

        // Build canonical GoalData with flattened structure
        return GoalData(
            id: goalUUID,
            startDate: row.goalStartDate,
            targetDate: row.goalTargetDate,
            actionPlan: row.goalActionPlan,
            expectedTermLength: row.goalExpectedTermLength,
            expectationId: expectationUUID,
            title: row.expectationTitle,
            detailedDescription: row.expectationDetailedDescription,
            freeformNotes: row.expectationFreeformNotes,
            expectationImportance: row.expectationImportance,
            expectationUrgency: row.expectationUrgency,
            logTime: row.expectationLogTime,
            measureTargets: measureTargets,
            valueAlignments: valueAlignments,
            termAssignment: termAssignment
        )
    }

    // MARK: - SQL Result Row Types

    /// Main SQL query result row (one row per goal)
    ///
    /// **Source**: Copied from GoalRepository.swift GoalQueryRow (line 354)
    /// **Note**: String IDs (not UUID) because SQL returns TEXT
    private struct GoalQueryRow: Decodable, FetchableRecord, Sendable {
        // Goal fields (prefixed to avoid column name collisions)
        let goalId: String
        let goalStartDate: Date?
        let goalTargetDate: Date?
        let goalActionPlan: String?
        let goalExpectedTermLength: Int?

        // Expectation fields
        let expectationId: String
        let expectationTitle: String?
        let expectationDetailedDescription: String?
        let expectationFreeformNotes: String?
        let expectationLogTime: Date
        let expectationImportance: Int
        let expectationUrgency: Int

        // JSON aggregations (as strings, parsed later)
        let measuresJson: String        // Array of measure objects
        let valuesJson: String          // Array of value objects
        let termAssignmentJson: String? // Single term object (or NULL)
    }

    /// Nested JSON structure for measures
    ///
    /// **Source**: Copied from GoalRepository.swift MeasureJsonRow (line 378)
    private struct MeasureJsonRow: Decodable, Sendable {
        let expectationMeasureId: String
        let targetValue: Double
        let expectationMeasureFreeformNotes: String?
        let measureId: String
        let measureTitle: String?
        let measureUnit: String
        let measureType: String
        let measureDetailedDescription: String?
        let measureFreeformNotes: String?
        let measureLogTime: Date
        let measureCanonicalUnit: String?
        let measureConversionFactor: Double?
        let expectationMeasureCreatedAt: Date
    }

    /// Nested JSON structure for values
    ///
    /// **Source**: Copied from GoalRepository.swift ValueJsonRow (line 395)
    private struct ValueJsonRow: Decodable, Sendable {
        let relevanceId: String
        let alignmentStrength: Int?
        let relevanceNotes: String?
        let valueId: String
        let valueTitle: String
        let valueDetailedDescription: String?
        let valueFreeformNotes: String?
        let valuePriority: Int
        let valueLevel: String
        let valueLifeDomain: String?
        let valueAlignmentGuidance: String?
        let valueLogTime: Date
        let relevanceCreatedAt: Date
    }

    /// Nested JSON structure for term assignment (single object, not array)
    ///
    /// **Source**: Copied from GoalRepository.swift TermAssignmentJsonRow (line 412)
    private struct TermAssignmentJsonRow: Decodable, Sendable {
        let assignmentId: String
        let termId: String
        let assignmentOrder: Int?
        let createdAt: Date
    }
}

// MARK: - Sendable Conformance

// GoalRepository_v3 is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - All methods are async (thread-safe)
// - Safe to pass between actor boundaries
extension GoalRepository: @unchecked Sendable {}
