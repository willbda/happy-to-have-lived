//
// ObligationRepository.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Repository for Obligation entities
// PATTERN: Simple JOIN query (Obligation + Expectation)
// SIMPLER THAN: GoalRepository (no measures/values), ActionRepository (no measurements)
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Obligation entities
///
/// **Architecture**: Simple pattern without BaseRepository
/// - Obligation + Expectation JOIN (1:1 relationship)
/// - No complex relationships to manage
/// - Returns ObligationWithDetails for UI consumption
///
/// **Pattern**: Direct SQL queries with SQLiteData
/// - Uses #sql macro for type safety where possible
/// - Manual SQL for JOIN queries
///
/// **What This Repository Provides**:
/// - fetchAll(): All obligations with expectation details
/// - fetchById(): Single obligation by ID
/// - exists(): Check if obligation exists
///
public final class ObligationRepository: Sendable {
    private let database: any DatabaseReader

    public init(database: any DatabaseReader) {
        self.database = database
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
    public func fetchAll() async throws -> [ObligationWithDetails] {
        try await database.read { db in
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
        try await database.read { db in
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
    public func exists(_ id: UUID) async throws -> Bool {
        try await database.read { db in
            let sql = "SELECT 1 FROM obligations WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
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
