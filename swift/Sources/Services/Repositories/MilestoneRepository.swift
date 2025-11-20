//
// MilestoneRepository.swift
// Written by Claude Code on 2025-11-19
// Refactored by Claude Code on 2025-11-19
//
// PURPOSE: Repository for Milestone entities
// PATTERN: BaseRepository with simple JOIN query (Milestone + Expectation)
// EXTENDS: BaseRepository<MilestoneWithDetails> for consistency with other repositories
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Milestone entities
///
/// **Architecture**: Extends BaseRepository<MilestoneWithDetails>
/// - Milestone + Expectation JOIN (1:1 relationship)
/// - No complex relationships to manage
/// - Returns MilestoneWithDetails for UI consumption
///
/// **Pattern**: BaseRepository with manual SQL for JOINs
/// - Inherits error mapping, date filtering, pagination from BaseRepository
/// - Manual SQL for JOIN queries (1:1 relationship)
///
/// **What BaseRepository Provides**:
/// - Automatic error mapping (DatabaseError → ValidationError)
/// - Date filtering helpers (buildDateFilter)
/// - Read/write wrappers with error handling
/// - Pagination support (fetch(limit:offset:), fetchRecent(limit:))
///
/// **What This Repository Adds**:
/// - fetchAll(): All milestones with expectation details
/// - fetchById(): Single milestone by ID
/// - exists(): Check if milestone exists
/// - fetchByStatus(): Filter by milestone status
/// - fetchUpcoming(): Filter to upcoming milestones
///
public final class MilestoneRepository: BaseRepository<MilestoneWithDetails> {

    public override init(database: any DatabaseWriter) {
        super.init(database: database)
    }

    /// Fetch all milestones with expectation details
    ///
    /// **Implementation**: Simple JOIN query
    /// - milestone INNER JOIN expectations
    /// - Returns MilestoneWithDetails (milestone + expectation)
    /// - Ordered by targetDate ASC (upcoming milestones first)
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// SELECT m.*, e.*
    /// FROM milestones m
    /// INNER JOIN expectations e ON m.expectationId = e.id
    /// ORDER BY m.targetDate ASC
    /// ```
    public override func fetchAll() async throws -> [MilestoneWithDetails] {
        try await read { db in
            let sql = """
                SELECT
                    m.id as milestoneId,
                    m.expectationId,
                    m.targetDate,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM milestones m
                INNER JOIN expectations e ON m.expectationId = e.id
                ORDER BY m.targetDate ASC
                """

            let rows = try MilestoneQueryRow.fetchAll(db, sql: sql)
            return rows.map { self.assembleMilestoneWithDetails(from: $0) }
        }
    }

    /// Fetch milestone by ID
    ///
    /// **Implementation**: Same as fetchAll() + WHERE m.id = ?
    public func fetchById(_ id: UUID) async throws -> MilestoneWithDetails? {
        try await read { db in
            let sql = """
                SELECT
                    m.id as milestoneId,
                    m.expectationId,
                    m.targetDate,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM milestones m
                INNER JOIN expectations e ON m.expectationId = e.id
                WHERE m.id = ?
                """

            guard let row = try MilestoneQueryRow.fetchOne(db, sql: sql, arguments: [id]) else {
                return nil
            }

            return self.assembleMilestoneWithDetails(from: row)
        }
    }

    /// Check if milestone exists by ID
    ///
    /// **Implementation**: Simple COUNT query
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            let sql = "SELECT 1 FROM milestones WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Fetch milestones filtered by date range for export
    ///
    /// **Implementation**: Same as fetchAll() + WHERE e.logTime BETWEEN ? AND ?
    /// **Date Filter**: Uses expectation.logTime (when milestone was created)
    /// **Pattern**: Uses BaseRepository.buildDateFilter() for consistency
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [MilestoneWithDetails] {
        // Early return if no filter (use fetchAll)
        guard startDate != nil || endDate != nil else {
            return try await fetchAll()
        }

        // Use BaseRepository helper for WHERE clause building
        let (whereClause, arguments) = buildDateFilter(
            from: startDate,
            to: endDate,
            dateColumn: "e.logTime"
        )

        return try await read { db in
            let sql = """
                SELECT
                    m.id as milestoneId,
                    m.expectationId,
                    m.targetDate,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM milestones m
                INNER JOIN expectations e ON m.expectationId = e.id
                \(whereClause)
                ORDER BY m.targetDate ASC
                """

            let rows = try MilestoneQueryRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { self.assembleMilestoneWithDetails(from: $0) }
        }
    }

    // MARK: - Status-Based Queries

    /// Fetch milestones by calculated status
    ///
    /// **Implementation**: Uses CASE statement to calculate status, then filter
    /// **Status Calculation**: Based on targetDate proximity to current date
    /// - upcoming: targetDate > now + 7 days
    /// - due: targetDate between now and now + 7 days
    /// - overdue: targetDate < now
    ///
    /// **Use Case**: Dashboard showing "due this week" or "overdue" milestones
    /// **TODO**: Phase 3 - Add filtering UI to MilestonesListView
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// SELECT ... FROM milestones m JOIN expectations e
    /// WHERE (status = 'upcoming' AND targetDate > date('now', '+7 days'))
    ///    OR (status = 'due' AND targetDate >= date('now') AND targetDate <= date('now', '+7 days'))
    ///    OR (status = 'overdue' AND targetDate < date('now'))
    /// ```
    public func fetchByStatus(_ status: MilestoneStatus) async throws -> [MilestoneWithDetails] {
        try await read { db in
            // Build WHERE clause based on status
            let whereClause: String
            switch status {
            case .upcoming:
                whereClause = "WHERE m.targetDate > date('now', '+7 days')"
            case .due:
                whereClause = "WHERE m.targetDate >= date('now') AND m.targetDate <= date('now', '+7 days')"
            case .overdue:
                whereClause = "WHERE m.targetDate < date('now')"
            case .completed:
                // Completed status would require a separate completion tracking field
                // For now, return empty array (milestones don't have completion tracking yet)
                return []
            }

            let sql = """
                SELECT
                    m.id as milestoneId,
                    m.expectationId,
                    m.targetDate,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM milestones m
                INNER JOIN expectations e ON m.expectationId = e.id
                \(whereClause)
                ORDER BY m.targetDate ASC
                """

            let rows = try MilestoneQueryRow.fetchAll(db, sql: sql)
            return rows.map { self.assembleMilestoneWithDetails(from: $0) }
        }
    }

    /// Fetch upcoming milestones within specified days
    ///
    /// **Implementation**: Filter to targetDate within N days from now
    /// **Default**: 30 days (next month)
    /// **Use Case**: "Upcoming milestones" dashboard widget
    /// **TODO**: Phase 3 - Add date range filtering to MilestonesListView
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// WHERE targetDate BETWEEN date('now') AND date('now', '+N days')
    /// ORDER BY targetDate ASC
    /// ```
    public func fetchUpcoming(days: Int = 30) async throws -> [MilestoneWithDetails] {
        try await read { db in
            let sql = """
                SELECT
                    m.id as milestoneId,
                    m.expectationId,
                    m.targetDate,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM milestones m
                INNER JOIN expectations e ON m.expectationId = e.id
                WHERE m.targetDate BETWEEN date('now') AND date('now', '+\(days) days')
                ORDER BY m.targetDate ASC
                """

            let rows = try MilestoneQueryRow.fetchAll(db, sql: sql)
            return rows.map { self.assembleMilestoneWithDetails(from: $0) }
        }
    }

    // MARK: - Private Helpers

    /// Assemble MilestoneWithDetails from query row
    ///
    /// **Pattern**: Construct Milestone and Expectation from flattened row
    ///
    /// - Parameter row: MilestoneQueryRow with all fields
    /// - Returns: Assembled MilestoneWithDetails
    private func assembleMilestoneWithDetails(from row: MilestoneQueryRow) -> MilestoneWithDetails {
        let milestone = Milestone(
            expectationId: row.expectationId,
            targetDate: row.targetDate,
            id: row.milestoneId
        )

        let expectation = Expectation(
            title: row.title,
            detailedDescription: row.detailedDescription,
            freeformNotes: row.freeformNotes,
            expectationType: row.expectationType,
            expectationImportance: row.expectationImportance,
            expectationUrgency: row.expectationUrgency,
            logTime: row.logTime,
            id: row.expectationId
        )

        return MilestoneWithDetails(
            milestone: milestone,
            expectation: expectation
        )
    }

    /// Query row structure matching SQL SELECT columns
    ///
    /// **Fields**: Milestone columns + Expectation columns (flattened from JOIN)
    ///
    /// **Usage**: Intermediate struct for SQL → MilestoneWithDetails transformation
    private struct MilestoneQueryRow: Decodable, FetchableRecord {
        // Milestone fields
        let milestoneId: UUID
        let expectationId: UUID
        let targetDate: Date

        // Expectation fields
        let title: String?
        let detailedDescription: String?
        let freeformNotes: String?
        let logTime: Date
        let expectationType: ExpectationType
        let expectationImportance: Int
        let expectationUrgency: Int
    }
}

// MARK: - Sendable Conformance

// MilestoneRepository is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - All methods are async (thread-safe)
// - Safe to pass between actor boundaries
extension MilestoneRepository: @unchecked Sendable {}

// MARK: - Result Type

/// Milestone with full expectation details for UI consumption
///
/// **Purpose**: Provides all data needed to display a milestone
/// - milestone: Core Milestone entity (id, expectationId, targetDate)
/// - expectation: Full Expectation details (title, description, importance, urgency)
///
/// **Usage**: Returned by MilestoneRepository queries, consumed by MilestonesListViewModel
public struct MilestoneWithDetails: Identifiable, Hashable, Sendable {
    public let milestone: Milestone
    public let expectation: Expectation

    public var id: UUID { milestone.id }

    public init(milestone: Milestone, expectation: Expectation) {
        self.milestone = milestone
        self.expectation = expectation
    }
}
