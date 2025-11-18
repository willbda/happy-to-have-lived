//
// MeasureDeduplicationCoordinator.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE: One-off utility for merging duplicate measures
// USAGE: Called from MeasureDeduplicationView (Debug UI)
//
// PATTERN: Coordinator for multi-table atomic operations
// - Queries duplicates via MeasureRepository
// - Updates FK references (measuredActions, expectationMeasures)
// - Deletes duplicate measures
// - All operations in single transaction
//
// ONTOLOGICAL NOTE:
// This is historical cleanup, not ongoing architecture.
// Future duplicates prevented by MeasureCoordinator.getOrCreate()
//

import Dependencies
import Foundation
import Models
import SQLiteData

/// Result of merging duplicate measures
public struct MeasureMergeResult: Sendable {
    public let canonicalId: UUID
    public let canonicalTitle: String
    public let mergedIds: [UUID]
    public let measuredActionsUpdated: Int
    public let expectationMeasuresUpdated: Int
    public let duplicatesDeleted: Int

    public var summary: String {
        """
        Merged \(mergedIds.count) duplicate(s) of "\(canonicalTitle)" into canonical measure
        - Updated \(measuredActionsUpdated) measured actions
        - Updated \(expectationMeasuresUpdated) expectation measures
        - Deleted \(duplicatesDeleted) duplicate measure(s)
        Canonical ID: \(canonicalId)
        """
    }
}

/// Duplicate measure group (for discovery)
public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String  // compound key: "\(unit)|\(measureType)"
    public let unit: String
    public let measureType: String
    public let measures: [MeasureData]

    public var canonicalMeasure: MeasureData {
        // Select canonical: oldest by logTime, or most-used
        measures.sorted { lhs, rhs in
            lhs.logTime < rhs.logTime
        }.first!
    }

    public var duplicates: [MeasureData] {
        Array(measures.dropFirst())
    }
}

/// Safely merges duplicate measures
///
/// **Usage**:
/// ```swift
/// let coordinator = MeasureDeduplicationCoordinator(database: database)
///
/// // Find all duplicates
/// let duplicates = try await coordinator.findAllDuplicates()
///
/// // Preview merge (dry run)
/// let preview = try await coordinator.previewMerge(group: duplicates[0])
///
/// // Execute merge
/// let result = try await coordinator.merge(group: duplicates[0])
/// print(result.summary)
/// ```
public final class MeasureDeduplicationCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    // MARK: - Discovery

    /// Find all measures with duplicates (group by unit + measureType)
    ///
    /// **Returns**: Array of duplicate groups (only groups with 2+ measures)
    public func findAllDuplicates() async throws -> [DuplicateGroup] {
        let repository = MeasureRepository(database: database)
        let allMeasures = try await repository.fetchAll()

        // Group by compound key (unit, measureType)
        let grouped = Dictionary(grouping: allMeasures) { measure in
            "\(measure.unit.lowercased())|\(measure.measureType.lowercased())"
        }

        // Filter to only groups with 2+ entries
        let duplicateGroups = grouped.compactMap { (key, measures) -> DuplicateGroup? in
            guard measures.count > 1 else { return nil }

            let parts = key.split(separator: "|")
            return DuplicateGroup(
                id: key,
                unit: String(parts[0]),
                measureType: String(parts[1]),
                measures: measures
            )
        }

        return duplicateGroups.sorted { $0.unit < $1.unit }
    }

    // MARK: - Preview

    /// Preview what would be merged (dry run)
    ///
    /// **Parameters**:
    /// - group: Duplicate group to merge
    ///
    /// **Returns**: Preview of operations (no database changes)
    public func previewMerge(group: DuplicateGroup) async throws -> MeasureMergeResult {
        let canonical = group.canonicalMeasure
        let mergeIds = group.duplicates.map { $0.id }

        return try await database.read { db in
            // Count references that would be updated (using raw SQL)
            var measuredActionsCount = 0
            var expectationMeasuresCount = 0

            for measureId in mergeIds {
                let actionSQL = "SELECT COUNT(*) FROM measuredActions WHERE measureId = ?"
                measuredActionsCount += try Int.fetchOne(db, sql: actionSQL, arguments: [measureId.uuidString.lowercased()]) ?? 0

                let goalSQL = "SELECT COUNT(*) FROM expectationMeasures WHERE measureId = ?"
                expectationMeasuresCount += try Int.fetchOne(db, sql: goalSQL, arguments: [measureId.uuidString.lowercased()]) ?? 0
            }

            return MeasureMergeResult(
                canonicalId: canonical.id,
                canonicalTitle: canonical.displayTitle,
                mergedIds: mergeIds,
                measuredActionsUpdated: measuredActionsCount,
                expectationMeasuresUpdated: expectationMeasuresCount,
                duplicatesDeleted: mergeIds.count
            )
        }
    }

    // MARK: - Execution

    /// Merge duplicate measures into canonical measure
    ///
    /// **Pattern**: Atomic multi-table transaction
    /// 1. Update all measuredActions references
    /// 2. Update all expectationMeasures references
    /// 3. Delete duplicate measures
    /// 4. CloudKit sync picks up all changes automatically
    ///
    /// **CRITICAL**: Uses SQLiteData query builders for CloudKit compatibility
    public func merge(group: DuplicateGroup) async throws -> MeasureMergeResult {
        let canonical = group.canonicalMeasure
        let mergeIds = group.duplicates.map { $0.id }

        guard !mergeIds.isEmpty else {
            throw ValidationError.missingRequiredField("No duplicates to merge")
        }

        return try await database.write { db in
            var measuredActionsUpdated = 0
            var expectationMeasuresUpdated = 0

            // Step 1: Update measuredActions references (using raw SQL)
            for mergeId in mergeIds {
                let updateSQL = """
                UPDATE measuredActions
                SET measureId = ?
                WHERE measureId = ?
                """
                try db.execute(
                    sql: updateSQL,
                    arguments: [canonical.id.uuidString.lowercased(), mergeId.uuidString.lowercased()]
                )

                // Count updated rows
                let countSQL = "SELECT changes()"
                measuredActionsUpdated += try Int.fetchOne(db, sql: countSQL) ?? 0
            }

            // Step 2: Update expectationMeasures references (using raw SQL)
            for mergeId in mergeIds {
                let updateSQL = """
                UPDATE expectationMeasures
                SET measureId = ?
                WHERE measureId = ?
                """
                try db.execute(
                    sql: updateSQL,
                    arguments: [canonical.id.uuidString.lowercased(), mergeId.uuidString.lowercased()]
                )

                // Count updated rows
                let countSQL = "SELECT changes()"
                expectationMeasuresUpdated += try Int.fetchOne(db, sql: countSQL) ?? 0
            }

            // Step 3: Delete duplicate measures
            for mergeId in mergeIds {
                try Measure.find(mergeId).delete().execute(db)
            }

            return MeasureMergeResult(
                canonicalId: canonical.id,
                canonicalTitle: canonical.displayTitle,
                mergedIds: mergeIds,
                measuredActionsUpdated: measuredActionsUpdated,
                expectationMeasuresUpdated: expectationMeasuresUpdated,
                duplicatesDeleted: mergeIds.count  // We know we deleted all of them
            )
        }
    }
}