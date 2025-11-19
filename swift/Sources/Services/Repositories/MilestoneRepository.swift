//
// MilestoneRepository.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Repository for Milestone entities
// PATTERN: Simple JOIN query (Milestone + Expectation)
// SIMPLER THAN: GoalRepository (no measures/values), ActionRepository (no measurements)
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Repository for managing Milestone entities
///
/// **Architecture**: Simple pattern without BaseRepository
/// - Milestone + Expectation JOIN (1:1 relationship)
/// - No complex relationships to manage
/// - Returns MilestoneWithDetails for UI consumption
///
/// **Pattern**: Direct SQL queries with SQLiteData
/// - Uses #sql macro for type safety where possible
/// - Manual SQL for JOIN queries
///
/// **What This Repository Provides**:
/// - fetchAll(): All milestones with expectation details
/// - fetchById(): Single milestone by ID
/// - exists(): Check if milestone exists
///
public final class MilestoneRepository: Sendable {
    private let database: any DatabaseReader

    public init(database: any DatabaseReader) {
        self.database = database
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
    public func fetchAll() async throws -> [MilestoneWithDetails] {
        try await database.read { db in
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
            return rows.map { assembleMilestoneWithDetails(from: $0) }
        }
    }

    /// Fetch milestone by ID
    ///
    /// **Implementation**: Same as fetchAll() + WHERE m.id = ?
    public func fetchById(_ id: UUID) async throws -> MilestoneWithDetails? {
        try await database.read { db in
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

            return assembleMilestoneWithDetails(from: row)
        }
    }

    /// Check if milestone exists by ID
    ///
    /// **Implementation**: Simple COUNT query
    public func exists(_ id: UUID) async throws -> Bool {
        try await database.read { db in
            let sql = "SELECT 1 FROM milestones WHERE id = ? LIMIT 1"
            return try Row.fetchOne(db, sql: sql, arguments: [id]) != nil
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
            id: row.milestoneId,
            expectationId: row.expectationId,
            targetDate: row.targetDate
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
