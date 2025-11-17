//
//  EmbeddingBackfillService.swift
//  Ten Week Goal App
//
//  Written by Claude Code on 2025-11-16
//
//  PURPOSE: Background service to generate missing semantic embeddings
//  PATTERN: Self-healing cache - runs on app launch to fill gaps
//
//  USE CASES:
//  - Backfill embeddings for goals created before semantic infrastructure
//  - Generate embeddings for CSV-imported entities
//  - Ensure all entities have embeddings for future semantic features
//

import Foundation
import Models
import SQLiteData

/// Background service to ensure all entities have semantic embeddings
///
/// Runs automatically on app launch (low priority) to fill any gaps in the
/// semantic embeddings cache. This ensures that:
/// - Pre-semantic goals/values get embeddings
/// - CSV-imported entities are ready for deduplication
/// - Future semantic features (word clouds, alignment heatmaps) have data
///
/// ## Usage
/// ```swift
/// // In App.swift or AppDelegate
/// .task {
///     Task.detached(priority: .background) {
///         await EmbeddingBackfillService.run(database: database)
///     }
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
public enum EmbeddingBackfillService {

    /// Run backfill for all entity types
    /// - Parameter database: Database writer to use
    public static func run(database: any DatabaseWriter) async {
        print("🔄 [EmbeddingBackfill] Starting background embedding generation...")

        let start = Date()

        // Run backfills concurrently for better performance
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await backfillGoals(database: database)
            }

            group.addTask {
                await backfillPersonalValues(database: database)
            }

            // Future: Add actions when needed
            // group.addTask {
            //     await backfillActions(database: database)
            // }
        }

        let duration = Date().timeIntervalSince(start)
        print("✅ [EmbeddingBackfill] Complete in \(String(format: "%.1f", duration))s")
    }

    // MARK: - Goal Backfill

    private static func backfillGoals(database: any DatabaseWriter) async {
        do {
            // 1. Fetch all goals (GoalData is canonical type)
            let repository = GoalRepository(database: database)
            let allGoals = try await repository.fetchAll()

            // 2. Find which goals already have embeddings
            let embeddingRepo = EmbeddingCacheRepository(database: database)
            let existingEmbeddings = try await embeddingRepo.fetchAllByType("goal")
            let embeddedGoalIds = Set(existingEmbeddings.map { $0.entityId })

            // 3. Filter to goals missing embeddings
            let missingEmbeddings = allGoals.filter { !embeddedGoalIds.contains($0.id) }

            guard !missingEmbeddings.isEmpty else {
                print("   ✓ Goals: All \(allGoals.count) already have embeddings")
                return
            }

            print("   🔄 Goals: Generating \(missingEmbeddings.count)/\(allGoals.count) missing embeddings...")

            // 4. Generate embeddings
            let semanticService = SemanticService(database: database, configuration: .default)
            var successCount = 0

            for goal in missingEmbeddings {
                do {
                    _ = try await semanticService.generateEmbedding(for: goal.title ?? "Untitled")
                    successCount += 1
                } catch {
                    // Log but continue (best effort)
                    print("   ⚠️  Failed to generate embedding for goal '\(goal.title ?? "Untitled")': \(error)")
                }
            }

            print("   ✅ Goals: Generated \(successCount)/\(missingEmbeddings.count) embeddings")

        } catch {
            print("   ❌ Goals backfill failed: \(error)")
        }
    }

    // MARK: - PersonalValue Backfill

    private static func backfillPersonalValues(database: any DatabaseWriter) async {
        do {
            // 1. Fetch all values (PersonalValueData is canonical type)
            let repository = PersonalValueRepository(database: database)
            let allValues = try await repository.fetchAll()

            // 2. Find which values already have embeddings
            let embeddingRepo = EmbeddingCacheRepository(database: database)
            let existingEmbeddings = try await embeddingRepo.fetchAllByType("value")
            let embeddedValueIds = Set(existingEmbeddings.map { $0.entityId })

            // 3. Filter to values missing embeddings
            let missingEmbeddings = allValues.filter { !embeddedValueIds.contains($0.id) }

            guard !missingEmbeddings.isEmpty else {
                print("   ✓ Values: All \(allValues.count) already have embeddings")
                return
            }

            print("   🔄 Values: Generating \(missingEmbeddings.count)/\(allValues.count) missing embeddings...")

            // 4. Generate embeddings
            let semanticService = SemanticService(database: database, configuration: .default)
            var successCount = 0

            for value in missingEmbeddings {
                do {
                    _ = try await semanticService.generateEmbedding(for: value.title)
                    successCount += 1
                } catch {
                    // Log but continue (best effort)
                    print("   ⚠️  Failed to generate embedding for value '\(value.title)': \(error)")
                }
            }

            print("   ✅ Values: Generated \(successCount)/\(missingEmbeddings.count) embeddings")

        } catch {
            print("   ❌ Values backfill failed: \(error)")
        }
    }

    // MARK: - Utility Methods

    /// Force regeneration of all embeddings (use for testing or after model changes)
    /// - Parameter database: Database writer to use
    /// - Warning: This will delete and recreate all embeddings
    public static func forceRegenerate(database: any DatabaseWriter) async {
        print("⚠️  [EmbeddingBackfill] Force regenerating ALL embeddings...")

        do {
            // Delete all existing embeddings
            let embeddingRepo = EmbeddingCacheRepository(database: database)
            try await database.write { db in
                try db.execute(sql: "DELETE FROM semanticEmbeddings")
            }

            // Run normal backfill (will regenerate all)
            await run(database: database)

        } catch {
            print("❌ [EmbeddingBackfill] Force regenerate failed: \(error)")
        }
    }

    /// Get backfill statistics without running backfill
    /// - Parameter database: Database writer (used for read operations only)
    /// - Returns: Statistics about embedding coverage
    public static func getStats(database: any DatabaseWriter) async -> BackfillStats {
        var stats = BackfillStats()

        do {
            // Goals
            let goalRepo = GoalRepository(database: database)
            let allGoals = try await goalRepo.fetchAll()
            let embeddingRepo = EmbeddingCacheRepository(database: database)
            let goalEmbeddings = try await embeddingRepo.fetchAllByType("goal")

            stats.goalTotal = allGoals.count
            stats.goalEmbedded = goalEmbeddings.count

            // Values
            let valueRepo = PersonalValueRepository(database: database)
            let allValues = try await valueRepo.fetchAll()
            let valueEmbeddings = try await embeddingRepo.fetchAllByType("value")

            stats.valueTotal = allValues.count
            stats.valueEmbedded = valueEmbeddings.count

        } catch {
            print("⚠️  Failed to get backfill stats: \(error)")
        }

        return stats
    }
}

// MARK: - Statistics

public struct BackfillStats {
    public var goalTotal: Int = 0
    public var goalEmbedded: Int = 0
    public var valueTotal: Int = 0
    public var valueEmbedded: Int = 0

    public var goalCoveragePercent: Int {
        guard goalTotal > 0 else { return 0 }
        return Int((Double(goalEmbedded) / Double(goalTotal)) * 100)
    }

    public var valueCoveragePercent: Int {
        guard valueTotal > 0 else { return 0 }
        return Int((Double(valueEmbedded) / Double(valueTotal)) * 100)
    }

    public var description: String {
        """
        Embedding Coverage:
        - Goals: \(goalEmbedded)/\(goalTotal) (\(goalCoveragePercent)%)
        - Values: \(valueEmbedded)/\(valueTotal) (\(valueCoveragePercent)%)
        """
    }
}
