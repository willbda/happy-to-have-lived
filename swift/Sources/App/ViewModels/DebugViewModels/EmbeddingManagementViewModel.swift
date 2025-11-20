//
// EmbeddingManagementViewModel.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Manage semantic embeddings cache - purge, regenerate, view stats
// PATTERN: @Observable ViewModel with @MainActor for UI updates
//
// CAPABILITIES:
// - View embedding statistics (counts, cache bloat, coverage)
// - Purge orphaned embeddings (43x cache bloat cleanup)
// - Regenerate missing embeddings (backfill)
// - Force regenerate all embeddings (nuclear option)
//

import Foundation
import SwiftUI
import Models
import Services
import Database
import Dependencies
import GRDB

@available(iOS 26.0, macOS 26.0, *)
@Observable
@MainActor
public final class EmbeddingManagementViewModel {

    // MARK: - Observable State

    var isLoading: Bool = false
    var errorMessage: String?
    var stats: EmbeddingStats?
    var operationResult: String?

    var hasError: Bool { errorMessage != nil }
    var hasResult: Bool { operationResult != nil }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    // MARK: - Initialization

    public init() {}

    // MARK: - Statistics

    /// Load current embedding statistics
    public func loadStats() async {
        isLoading = true
        errorMessage = nil
        operationResult = nil

        do {
            let embeddingStats = try await fetchEmbeddingStats()
            stats = embeddingStats
        } catch {
            errorMessage = "Failed to load statistics: \(error.localizedDescription)"
            print("❌ EmbeddingManagement loadStats error: \(error)")
        }

        isLoading = false
    }

    /// Fetch embedding statistics from database
    private func fetchEmbeddingStats() async throws -> EmbeddingStats {
        try await database.read { db in
            // Count total embeddings by entity type
            let sql = """
                SELECT
                    entityType,
                    sourceVariant,
                    COUNT(*) as count,
                    COUNT(DISTINCT entityId) as uniqueEntities
                FROM semanticEmbeddings
                WHERE entityType != 'semantic_cache'
                GROUP BY entityType, sourceVariant
                ORDER BY entityType, sourceVariant
                """

            let rows = try Row.fetchAll(db, sql: sql)

            var stats = EmbeddingStats()

            for row in rows {
                let entityType: String = row["entityType"]
                let sourceVariant: String = row["sourceVariant"]
                let count: Int = row["count"]
                let uniqueEntities: Int = row["uniqueEntities"]

                switch (entityType, sourceVariant) {
                case ("goal", "title_only"):
                    stats.goalTitleOnlyCount = count
                    stats.goalTitleOnlyUnique = uniqueEntities
                case ("goal", "full_context"):
                    stats.goalFullContextCount = count
                    stats.goalFullContextUnique = uniqueEntities
                case ("value", "title_only"):
                    stats.valueTitleOnlyCount = count
                    stats.valueTitleOnlyUnique = uniqueEntities
                case ("value", "full_context"):
                    stats.valueFullContextCount = count
                    stats.valueFullContextUnique = uniqueEntities
                case ("action", "title_only"):
                    stats.actionTitleOnlyCount = count
                    stats.actionTitleOnlyUnique = uniqueEntities
                case ("action", "full_context"):
                    stats.actionFullContextCount = count
                    stats.actionFullContextUnique = uniqueEntities
                case ("measure", "title_only"):
                    stats.measureTitleOnlyCount = count
                    stats.measureTitleOnlyUnique = uniqueEntities
                case ("measure", "full_context"):
                    stats.measureFullContextCount = count
                    stats.measureFullContextUnique = uniqueEntities
                case ("term", "title_only"):
                    stats.termTitleOnlyCount = count
                    stats.termTitleOnlyUnique = uniqueEntities
                case ("term", "full_context"):
                    stats.termFullContextCount = count
                    stats.termFullContextUnique = uniqueEntities
                default:
                    break
                }
            }

            // Count semantic_cache entries
            let cacheSQL = "SELECT COUNT(*) as count FROM semanticEmbeddings WHERE entityType = 'semantic_cache'"
            if let cacheRow = try Row.fetchOne(db, sql: cacheSQL) {
                stats.semanticCacheCount = cacheRow["count"]
            }

            // Calculate total size estimate (2048 bytes per embedding)
            let totalSQL = "SELECT COUNT(*) as count FROM semanticEmbeddings"
            if let totalRow = try Row.fetchOne(db, sql: totalSQL) {
                let totalCount: Int = totalRow["count"]
                stats.totalEmbeddings = totalCount
                stats.estimatedSizeMB = Double(totalCount * 2048) / (1024 * 1024)
            }

            return stats
        }
    }

    // MARK: - Purge Operations

    /// Purge orphaned embeddings (keep only latest version for each entity+variant)
    public func purgeOrphanedEmbeddings() async {
        isLoading = true
        errorMessage = nil
        operationResult = nil

        do {
            let deletedCount = try await database.write { db in
                // Delete orphaned embeddings (older versions when newer exists)
                let sql = """
                    DELETE FROM semanticEmbeddings
                    WHERE id IN (
                        SELECT se1.id
                        FROM semanticEmbeddings se1
                        WHERE EXISTS (
                            SELECT 1 FROM semanticEmbeddings se2
                            WHERE se2.entityId = se1.entityId
                              AND se2.entityType = se1.entityType
                              AND se2.sourceVariant = se1.sourceVariant
                              AND se2.generatedAt > se1.generatedAt
                        )
                    )
                    """

                try db.execute(sql: sql)

                // Return number of deleted rows
                return db.changesCount
            }

            operationResult = "✅ Purged \(deletedCount) orphaned embeddings"
            print("✅ Purged \(deletedCount) orphaned embeddings")

            // Reload stats to show updated counts
            await loadStats()

        } catch {
            errorMessage = "Failed to purge: \(error.localizedDescription)"
            print("❌ EmbeddingManagement purge error: \(error)")
        }

        isLoading = false
    }

    /// Delete ALL embeddings (nuclear option - use with caution)
    public func deleteAllEmbeddings() async {
        isLoading = true
        errorMessage = nil
        operationResult = nil

        do {
            let deletedCount = try await database.write { db in
                try db.execute(sql: "DELETE FROM semanticEmbeddings")
                return db.changesCount
            }

            operationResult = "⚠️ Deleted ALL \(deletedCount) embeddings"
            print("⚠️ Deleted ALL \(deletedCount) embeddings")

            // Reload stats to show zero counts
            await loadStats()

        } catch {
            errorMessage = "Failed to delete all: \(error.localizedDescription)"
            print("❌ EmbeddingManagement deleteAll error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Regeneration Operations

    /// Regenerate missing embeddings (backfill for entities without embeddings)
    public func regenerateMissingEmbeddings() async {
        isLoading = true
        errorMessage = nil
        operationResult = "🔄 Regenerating missing embeddings..."

        do {
            // Run backfill service
            await EmbeddingBackfillService.run(database: database)

            operationResult = "✅ Regenerated missing embeddings"
            print("✅ Regeneration complete")

            // Reload stats to show updated counts
            await loadStats()

        } catch {
            errorMessage = "Failed to regenerate: \(error.localizedDescription)"
            print("❌ EmbeddingManagement regenerate error: \(error)")
        }

        isLoading = false
    }

    /// Force regenerate ALL embeddings (delete + regenerate)
    public func forceRegenerateAll() async {
        isLoading = true
        errorMessage = nil
        operationResult = "🔄 Force regenerating ALL embeddings..."

        do {
            // Use backfill service's force regenerate
            await EmbeddingBackfillService.forceRegenerate(database: database)

            operationResult = "✅ Force regenerated all embeddings"
            print("✅ Force regeneration complete")

            // Reload stats to show updated counts
            await loadStats()

        } catch {
            errorMessage = "Failed to force regenerate: \(error.localizedDescription)"
            print("❌ EmbeddingManagement forceRegenerate error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Clear State

    public func clearResult() {
        operationResult = nil
    }

    public func clearError() {
        errorMessage = nil
    }
}

// MARK: - Statistics Model

public struct EmbeddingStats: Sendable {
    // Goal embeddings
    public var goalTitleOnlyCount: Int = 0
    public var goalTitleOnlyUnique: Int = 0
    public var goalFullContextCount: Int = 0
    public var goalFullContextUnique: Int = 0

    // Value embeddings
    public var valueTitleOnlyCount: Int = 0
    public var valueTitleOnlyUnique: Int = 0
    public var valueFullContextCount: Int = 0
    public var valueFullContextUnique: Int = 0

    // Action embeddings
    public var actionTitleOnlyCount: Int = 0
    public var actionTitleOnlyUnique: Int = 0
    public var actionFullContextCount: Int = 0
    public var actionFullContextUnique: Int = 0

    // Measure embeddings
    public var measureTitleOnlyCount: Int = 0
    public var measureTitleOnlyUnique: Int = 0
    public var measureFullContextCount: Int = 0
    public var measureFullContextUnique: Int = 0

    // Term embeddings
    public var termTitleOnlyCount: Int = 0
    public var termTitleOnlyUnique: Int = 0
    public var termFullContextCount: Int = 0
    public var termFullContextUnique: Int = 0

    // Semantic cache
    public var semanticCacheCount: Int = 0

    // Totals
    public var totalEmbeddings: Int = 0
    public var estimatedSizeMB: Double = 0

    // Computed properties
    public var goalTotalCount: Int {
        goalTitleOnlyCount + goalFullContextCount
    }

    public var goalBloatFactor: Double {
        guard goalTitleOnlyUnique > 0 else { return 0 }
        return Double(goalTitleOnlyCount) / Double(goalTitleOnlyUnique)
    }

    public var valueTotalCount: Int {
        valueTitleOnlyCount + valueFullContextCount
    }

    public var valueBloatFactor: Double {
        guard valueFullContextUnique > 0 else { return 0 }
        return Double(valueFullContextCount) / Double(valueFullContextUnique)
    }

    public var actionTotalCount: Int {
        actionTitleOnlyCount + actionFullContextCount
    }

    public var measureTotalCount: Int {
        measureTitleOnlyCount + measureFullContextCount
    }

    public var termTotalCount: Int {
        termTitleOnlyCount + termFullContextCount
    }

    public var hasOrphanedEmbeddings: Bool {
        goalBloatFactor > 2.0 || valueBloatFactor > 2.0
    }

    public var orphanedCount: Int {
        let goalOrphans = max(0, goalTitleOnlyCount - goalTitleOnlyUnique)
        let valueOrphans = max(0, valueFullContextCount - valueFullContextUnique)
        return goalOrphans + valueOrphans
    }
}
