//
// ContributionAmountBackfillService.swift
// Written by Claude Code on 2025-11-21
//
// PURPOSE: Backfill NULL contributionAmount values in actionGoalContributions table
// PATTERN: One-time data migration service, safe to run multiple times (idempotent)
//
// BACKGROUND:
// The contributionAmount and measureId fields were not being populated by ActionCoordinator
// until 2025-11-21. This service backfills existing records by matching measurements to goals.
//
// USAGE:
// ```swift
// let service = ContributionAmountBackfillService(database: database)
// let result = try await service.backfillContributions()
// print("Updated \(result.updated) contributions, skipped \(result.skipped)")
// ```
//
// SAFETY:
// - Idempotent: Safe to run multiple times (only updates NULL values)
// - In-app: CloudKit will sync changes automatically
// - Transactional: All updates in single transaction (all or nothing)
//

import Foundation
import Models
import SQLiteData
import GRDB

/// Service for backfilling contributionAmount in existing actionGoalContributions
public final class ContributionAmountBackfillService: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Result of backfill operation
    public struct BackfillResult: Sendable {
        public let updated: Int        // Records that were updated
        public let skipped: Int        // Records already populated
        public let notMatched: Int     // Records where no matching measurement found
        public let totalProcessed: Int // Total records examined

        public var summary: String {
            """
            Backfill Complete:
            - Updated: \(updated) contributions
            - Skipped (already populated): \(skipped)
            - No matching measurement: \(notMatched)
            - Total examined: \(totalProcessed)
            """
        }
    }

    /// Backfill contributionAmount for all existing actionGoalContributions
    ///
    /// Algorithm:
    /// 1. Find all contributions where contributionAmount IS NULL
    /// 2. For each contribution:
    ///    a. Query which measures the goal expects
    ///    b. Query which measurements the action has
    ///    c. Find intersection (matching measureId)
    ///    d. Update contributionAmount and measureId if match found
    ///
    /// - Returns: BackfillResult with counts of updated/skipped records
    /// - Throws: Database errors
    public func backfillContributions() async throws -> BackfillResult {
        try await database.write { db in
            // Step 1: Find all contributions needing backfill (SQLiteData syntax)
            let nullContributions = try ActionGoalContribution
                .where { contribution in
                    contribution.contributionAmount == nil || contribution.measureId == nil
                }
                .fetchAll(db)

            var updated = 0
            var notMatched = 0
            let totalProcessed = nullContributions.count

            // Step 2: Process each contribution
            for contribution in nullContributions {
                // Step 2a: Query which measures this goal expects
                guard let goal = try Goal.where { $0.id.eq(contribution.goalId) }.fetchOne(db) else {
                    continue  // Goal not found
                }

                let expectationMeasures = try ExpectationMeasure
                    .where { $0.expectationId.eq(goal.expectationId) }
                    .fetchAll(db)

                let expectedMeasureIds = Set(expectationMeasures.map { $0.measureId })

                // Step 2b: Query which measurements this action has
                let actionMeasurements = try MeasuredAction
                    .where { $0.actionId.eq(contribution.actionId) }
                    .fetchAll(db)

                // Step 2c: Find matching measurement
                let matchedMeasurement = actionMeasurements.first { measurement in
                    expectedMeasureIds.contains(measurement.measureId)
                }

                // Step 2d: Update if match found
                if let measurement = matchedMeasurement {
                    try db.execute(
                        sql: """
                            UPDATE actionGoalContributions
                            SET contributionAmount = ?, measureId = ?
                            WHERE id = ?
                            """,
                        arguments: [
                            measurement.value,
                            measurement.measureId.uuidString.lowercased(),
                            contribution.id.uuidString.lowercased(),
                        ]
                    )
                    updated += 1
                } else {
                    // No matching measurement found
                    // This is valid: action might contribute to goal in non-measurable way
                    notMatched += 1
                }
            }

            let skipped = totalProcessed - updated - notMatched

            return BackfillResult(
                updated: updated,
                skipped: skipped,
                notMatched: notMatched,
                totalProcessed: totalProcessed
            )
        }
    }

    /// Check how many contributions need backfilling (diagnostic)
    ///
    /// - Returns: Count of contributions with NULL contributionAmount or measureId
    public func countNeedingBackfill() async throws -> Int {
        try await database.read { db in
            // Use SQLiteData query builder syntax
            let count = try ActionGoalContribution
                .where { contribution in
                    contribution.contributionAmount == nil || contribution.measureId == nil
                }
                .fetchCount(db)
            return count
        }
    }
}
