//
// ObligationRepository.swift
// Written by Claude Code on 2025-11-19
// Refactored by Claude Code on 2025-11-19
//
// PURPOSE: Repository for Obligation entities
// PATTERN: BaseRepository with simple JOIN query (Obligation + Expectation)
// EXTENDS: BaseRepository<ObligationWithDetails> for consistency with other repositories
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Obligation entities
///
/// **Architecture**: Extends BaseRepository<ObligationWithDetails>
/// - Obligation + Expectation JOIN (1:1 relationship)
/// - No complex relationships to manage
/// - Returns ObligationWithDetails for UI consumption
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
/// - fetchAll(): All obligations with expectation details
/// - fetchById(): Single obligation by ID
/// - exists(): Check if obligation exists
/// - fetchByStatus(): Filter by obligation status
/// - fetchByUrgency(): Filter by urgency level
///
public final class ObligationRepository: BaseRepository<ObligationWithDetails> {

    public init(database: any DatabaseWriter) {
        super.init(database: database)
    }

    /// Fetch all obligations with expectation details
    ///
    /// **Implementation**: Simple JOIN query
    /// - obligation INNER JOIN expectations
    /// - Returns ObligationWithDetails (obligation + expectation)
    /// - Ordered by deadline ASC (urgent obligations first)
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// SELECT o.*, e.*
    /// FROM obligations o
    /// INNER JOIN expectations e ON o.expectationId = e.id
    /// ORDER BY o.deadline ASC
    /// ```
    public override func fetchAll() async throws -> [ObligationWithDetails] {
        try await read { db in
            let sql = """
                SELECT
                    o.id as obligationId,
                    o.expectationId,
                    o.deadline,
                    o.requestedBy,
                    o.consequence,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM obligations o
                INNER JOIN expectations e ON o.expectationId = e.id
                ORDER BY o.deadline ASC
                """

            let rows = try ObligationQueryRow.fetchAll(db, sql: sql)
            return rows.map { assembleObligationWithDetails(from: $0) }
        }
    }

    /// Fetch obligation by ID
    ///
    /// **Implementation**: Same as fetchAll() + WHERE o.id = ?
    public func fetchById(_ id: UUID) async throws -> ObligationWithDetails? {
        try await read { db in
            let sql = """
                SELECT
                    o.id as obligationId,
                    o.expectationId,
                    o.deadline,
                    o.requestedBy,
                    o.consequence,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM obligations o
                INNER JOIN expectations e ON o.expectationId = e.id
                WHERE o.id = ?
                """

            guard let row = try ObligationQueryRow.fetchOne(db, sql: sql, arguments: [id]) else {
                return nil
            }

            return assembleObligationWithDetails(from: row)
        }
    }

    /// Check if obligation exists by ID
    ///
    /// **Implementation**: Simple COUNT query
    public override func exists(_ id: UUID) async throws -> Bool {
        try await read { db in
            let sql = "SELECT 1 FROM obligations WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
        }
    }

    /// Fetch obligations filtered by date range for export
    ///
    /// **Implementation**: Same as fetchAll() + WHERE e.logTime BETWEEN ? AND ?
    /// **Date Filter**: Uses expectation.logTime (when obligation was created)
    /// **Pattern**: Uses BaseRepository.buildDateFilter() for consistency
    public override func fetchForExport(from startDate: Date?, to endDate: Date?) async throws -> [ObligationWithDetails] {
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
                    o.id as obligationId,
                    o.expectationId,
                    o.deadline,
                    o.requestedBy,
                    o.consequence,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM obligations o
                INNER JOIN expectations e ON o.expectationId = e.id
                \(whereClause)
                ORDER BY o.deadline ASC
                """

            let rows = try ObligationQueryRow.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { assembleObligationWithDetails(from: $0) }
        }
    }

    // MARK: - Status-Based Queries

    /// Fetch obligations by calculated status
    ///
    /// **Implementation**: Uses CASE statement to calculate status, then filter
    /// **Status Calculation**: Based on deadline proximity to current date
    /// - pending: deadline > now + 7 days
    /// - approaching: deadline between now and now + 7 days
    /// - overdue: deadline < now
    ///
    /// **Use Case**: Dashboard showing "approaching deadlines" or "overdue" obligations
    /// **TODO**: Phase 3 - Add filtering UI to ObligationsListView
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// SELECT ... FROM obligations o JOIN expectations e
    /// WHERE (status = 'pending' AND deadline > date('now', '+7 days'))
    ///    OR (status = 'approaching' AND deadline >= date('now') AND deadline <= date('now', '+7 days'))
    ///    OR (status = 'overdue' AND deadline < date('now'))
    /// ```
    public func fetchByStatus(_ status: ObligationStatus) async throws -> [ObligationWithDetails] {
        try await read { db in
            // Build WHERE clause based on status
            let whereClause: String
            switch status {
            case .pending:
                whereClause = "WHERE o.deadline > date('now', '+7 days')"
            case .approaching:
                whereClause = "WHERE o.deadline >= date('now') AND o.deadline <= date('now', '+7 days')"
            case .overdue:
                whereClause = "WHERE o.deadline < date('now')"
            case .completed:
                // Completed status would require a separate completion tracking field
                // For now, return empty array (obligations don't have completion tracking yet)
                return []
            }

            let sql = """
                SELECT
                    o.id as obligationId,
                    o.expectationId,
                    o.deadline,
                    o.requestedBy,
                    o.consequence,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM obligations o
                INNER JOIN expectations e ON o.expectationId = e.id
                \(whereClause)
                ORDER BY o.deadline ASC
                """

            let rows = try ObligationQueryRow.fetchAll(db, sql: sql)
            return rows.map { assembleObligationWithDetails(from: $0) }
        }
    }

    /// Fetch obligations by minimum urgency level
    ///
    /// **Implementation**: Filter to expectationUrgency >= threshold
    /// **Use Case**: "High urgency obligations" dashboard filter
    /// **Default**: No default (caller must specify threshold)
    /// **TODO**: Phase 3 - Add urgency filtering to ObligationsListView
    ///
    /// **SQL Pattern**:
    /// ```sql
    /// WHERE e.expectationUrgency >= ?
    /// ORDER BY e.expectationUrgency DESC, o.deadline ASC
    /// ```
    ///
    /// **Example**: fetchByUrgency(8) returns obligations with urgency >= 8
    public func fetchByUrgency(minimumUrgency: Int) async throws -> [ObligationWithDetails] {
        try await read { db in
            let sql = """
                SELECT
                    o.id as obligationId,
                    o.expectationId,
                    o.deadline,
                    o.requestedBy,
                    o.consequence,
                    e.id as expectationId,
                    e.title,
                    e.detailedDescription,
                    e.freeformNotes,
                    e.logTime,
                    e.expectationType,
                    e.expectationImportance,
                    e.expectationUrgency
                FROM obligations o
                INNER JOIN expectations e ON o.expectationId = e.id
                WHERE e.expectationUrgency >= ?
                ORDER BY e.expectationUrgency DESC, o.deadline ASC
                """

            let rows = try ObligationQueryRow.fetchAll(db, sql: sql, arguments: [minimumUrgency])
            return rows.map { assembleObligationWithDetails(from: $0) }
        }
    }

    // MARK: - Private Helpers

    /// Assemble ObligationWithDetails from query row
    ///
    /// **Pattern**: Construct Obligation and Expectation from flattened row
    ///
    /// - Parameter row: ObligationQueryRow with all fields
    /// - Returns: Assembled ObligationWithDetails
    private func assembleObligationWithDetails(from row: ObligationQueryRow) -> ObligationWithDetails {
        let obligation = Obligation(
            id: row.obligationId,
            expectationId: row.expectationId,
            deadline: row.deadline,
            requestedBy: row.requestedBy,
            consequence: row.consequence
        )

        let expectation = Expectation(
            id: row.expectationId,
            logTime: row.logTime,
            title: row.title,
            detailedDescription: row.detailedDescription,
            freeformNotes: row.freeformNotes,
            expectationType: row.expectationType,
            expectationImportance: row.expectationImportance,
            expectationUrgency: row.expectationUrgency
        )

        return ObligationWithDetails(
            obligation: obligation,
            expectation: expectation
        )
    }

    /// Query row structure matching SQL SELECT columns
    ///
    /// **Fields**: Obligation columns + Expectation columns (flattened from JOIN)
    ///
    /// **Usage**: Intermediate struct for SQL → ObligationWithDetails transformation
    private struct ObligationQueryRow: Decodable, FetchableRecord {
        // Obligation fields
        let obligationId: UUID
        let expectationId: UUID
        let deadline: Date
        let requestedBy: String?
        let consequence: String?

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

// ObligationRepository is Sendable because:
// - Inherits from BaseRepository (already Sendable)
// - No additional mutable state
// - All methods are async (thread-safe)
// - Safe to pass between actor boundaries
extension ObligationRepository: @unchecked Sendable {}

// MARK: - Result Type

/// Obligation with full expectation details for UI consumption
///
/// **Purpose**: Provides all data needed to display an obligation
/// - obligation: Core Obligation entity (id, expectationId, deadline, requestedBy, consequence)
/// - expectation: Full Expectation details (title, description, importance, urgency)
///
/// **Usage**: Returned by ObligationRepository queries, consumed by ObligationsListViewModel
public struct ObligationWithDetails: Identifiable, Hashable, Sendable {
    public let obligation: Obligation
    public let expectation: Expectation

    public var id: UUID { obligation.id }

    public init(obligation: Obligation, expectation: Expectation) {
        self.obligation = obligation
        self.expectation = expectation
    }
}
