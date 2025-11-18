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
import GRDB

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

            group.addTask {
                await backfillActions(database: database)
            }

            group.addTask {
                await backfillMeasures(database: database)
            }

            group.addTask {
                await backfillTimePeriods(database: database)
            }
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

            guard !allGoals.isEmpty else {
                print("   ✓ Goals: No goals to process")
                return
            }

            // 2. Find which goals already have BOTH embeddings (title_only + full_context)
            let existingTitleEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "goal",
                variant: .titleOnly
            )
            let existingFullEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "goal",
                variant: .fullContext
            )

            // 3. Filter to goals missing embeddings
            let missingTitleEmbeddings = allGoals.filter { !existingTitleEmbeddings.contains($0.id) }
            let missingFullEmbeddings = allGoals.filter { !existingFullEmbeddings.contains($0.id) }

            guard !missingTitleEmbeddings.isEmpty || !missingFullEmbeddings.isEmpty else {
                print("   ✓ Goals: All \(allGoals.count) have complete embeddings (title + full)")
                return
            }

            print("   🔄 Goals: Generating \(missingTitleEmbeddings.count) title-only + \(missingFullEmbeddings.count) full-context embeddings...")

            // 4. Generate embeddings using new EmbeddingGenerationService
            let embeddingService = EmbeddingGenerationService(database: database)
            var titleSuccessCount = 0
            var fullSuccessCount = 0

            // Generate title-only embeddings
            for goal in missingTitleEmbeddings {
                do {
                    _ = try await embeddingService.generateGoalEmbedding(goal: goal, variant: .titleOnly)
                    titleSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate title embedding for goal '\(goal.title ?? "Untitled")': \(error)")
                }
            }

            // Generate full-context embeddings
            for goal in missingFullEmbeddings {
                do {
                    _ = try await embeddingService.generateGoalEmbedding(goal: goal, variant: .fullContext)
                    fullSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate full embedding for goal '\(goal.title ?? "Untitled")': \(error)")
                }
            }

            print("   ✅ Goals: Generated \(titleSuccessCount) title-only + \(fullSuccessCount) full-context embeddings")

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

            guard !allValues.isEmpty else {
                print("   ✓ Values: No values to process")
                return
            }

            // 2. Find which values already have BOTH embeddings (title_only + full_context)
            let existingTitleEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "value",
                variant: .titleOnly
            )
            let existingFullEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "value",
                variant: .fullContext
            )

            // 3. Filter to values missing embeddings
            let missingTitleEmbeddings = allValues.filter { !existingTitleEmbeddings.contains($0.id) }
            let missingFullEmbeddings = allValues.filter { !existingFullEmbeddings.contains($0.id) }

            guard !missingTitleEmbeddings.isEmpty || !missingFullEmbeddings.isEmpty else {
                print("   ✓ Values: All \(allValues.count) have complete embeddings (title + full)")
                return
            }

            print("   🔄 Values: Generating \(missingTitleEmbeddings.count) title-only + \(missingFullEmbeddings.count) full-context embeddings...")

            // 4. Generate embeddings using new EmbeddingGenerationService
            let embeddingService = EmbeddingGenerationService(database: database)
            var titleSuccessCount = 0
            var fullSuccessCount = 0

            // Generate title-only embeddings
            for value in missingTitleEmbeddings {
                do {
                    _ = try await embeddingService.generateValueEmbedding(value: value, variant: .titleOnly)
                    titleSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate title embedding for value '\(value.title)': \(error)")
                }
            }

            // Generate full-context embeddings
            for value in missingFullEmbeddings {
                do {
                    _ = try await embeddingService.generateValueEmbedding(value: value, variant: .fullContext)
                    fullSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate full embedding for value '\(value.title)': \(error)")
                }
            }

            print("   ✅ Values: Generated \(titleSuccessCount) title-only + \(fullSuccessCount) full-context embeddings")

        } catch {
            print("   ❌ Values backfill failed: \(error)")
        }
    }

    // MARK: - Action Backfill

    private static func backfillActions(database: any DatabaseWriter) async {
        do {
            // 1. Fetch all actions (ActionData is canonical type)
            let repository = ActionRepository(database: database)
            let allActions = try await repository.fetchAll()

            guard !allActions.isEmpty else {
                print("   ✓ Actions: No actions to process")
                return
            }

            // 2. Find which actions already have BOTH embeddings
            let existingTitleEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "action",
                variant: .titleOnly
            )
            let existingFullEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "action",
                variant: .fullContext
            )

            // 3. Filter to actions missing embeddings
            let missingTitleEmbeddings = allActions.filter { !existingTitleEmbeddings.contains($0.id) }
            let missingFullEmbeddings = allActions.filter { !existingFullEmbeddings.contains($0.id) }

            guard !missingTitleEmbeddings.isEmpty || !missingFullEmbeddings.isEmpty else {
                print("   ✓ Actions: All \(allActions.count) have complete embeddings (title + full)")
                return
            }

            print("   🔄 Actions: Generating \(missingTitleEmbeddings.count) title-only + \(missingFullEmbeddings.count) full-context embeddings...")

            // 4. Generate embeddings
            let embeddingService = EmbeddingGenerationService(database: database)
            var titleSuccessCount = 0
            var fullSuccessCount = 0

            // Generate title-only embeddings
            for action in missingTitleEmbeddings {
                do {
                    _ = try await embeddingService.generateActionEmbedding(action: action, variant: .titleOnly)
                    titleSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate title embedding for action '\(action.title ?? "Untitled")': \(error)")
                }
            }

            // Generate full-context embeddings
            for action in missingFullEmbeddings {
                do {
                    _ = try await embeddingService.generateActionEmbedding(action: action, variant: .fullContext)
                    fullSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate full embedding for action '\(action.title ?? "Untitled")': \(error)")
                }
            }

            print("   ✅ Actions: Generated \(titleSuccessCount) title-only + \(fullSuccessCount) full-context embeddings")

        } catch {
            print("   ❌ Actions backfill failed: \(error)")
        }
    }

    // MARK: - Measure Backfill

    private static func backfillMeasures(database: any DatabaseWriter) async {
        do {
            // 1. Fetch all measures (MeasureData is canonical type)
            let repository = MeasureRepository(database: database)
            let allMeasures = try await repository.fetchAll()

            guard !allMeasures.isEmpty else {
                print("   ✓ Measures: No measures to process")
                return
            }

            // 2. Find which measures already have BOTH embeddings
            let existingTitleEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "measure",
                variant: .titleOnly
            )
            let existingFullEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "measure",
                variant: .fullContext
            )

            // 3. Filter to measures missing embeddings
            let missingTitleEmbeddings = allMeasures.filter { !existingTitleEmbeddings.contains($0.id) }
            let missingFullEmbeddings = allMeasures.filter { !existingFullEmbeddings.contains($0.id) }

            guard !missingTitleEmbeddings.isEmpty || !missingFullEmbeddings.isEmpty else {
                print("   ✓ Measures: All \(allMeasures.count) have complete embeddings (title + full)")
                return
            }

            print("   🔄 Measures: Generating \(missingTitleEmbeddings.count) title-only + \(missingFullEmbeddings.count) full-context embeddings...")

            // 4. Generate embeddings
            let embeddingService = EmbeddingGenerationService(database: database)
            var titleSuccessCount = 0
            var fullSuccessCount = 0

            // Generate title-only embeddings (unit + measureType for semantic matching)
            for measure in missingTitleEmbeddings {
                do {
                    _ = try await embeddingService.generateMeasureEmbedding(measure: measure, variant: .titleOnly)
                    titleSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate title embedding for measure '\(measure.unit) \(measure.measureType)': \(error)")
                }
            }

            // Generate full-context embeddings
            for measure in missingFullEmbeddings {
                do {
                    _ = try await embeddingService.generateMeasureEmbedding(measure: measure, variant: .fullContext)
                    fullSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate full embedding for measure '\(measure.unit) \(measure.measureType)': \(error)")
                }
            }

            print("   ✅ Measures: Generated \(titleSuccessCount) title-only + \(fullSuccessCount) full-context embeddings")

        } catch {
            print("   ❌ Measures backfill failed: \(error)")
        }
    }

    // MARK: - TimePeriod Backfill

    private static func backfillTimePeriods(database: any DatabaseWriter) async {
        do {
            // 1. Fetch all time periods (TimePeriodData is canonical type)
            let repository = TimePeriodRepository(database: database)
            let allPeriods = try await repository.fetchAll()

            guard !allPeriods.isEmpty else {
                print("   ✓ TimePeriods: No time periods to process")
                return
            }

            // 2. Find which time periods already have BOTH embeddings
            let existingTitleEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "term",
                variant: .titleOnly
            )
            let existingFullEmbeddings = try await fetchExistingEmbeddings(
                database: database,
                entityType: "term",
                variant: .fullContext
            )

            // 3. Filter to time periods missing embeddings
            let missingTitleEmbeddings = allPeriods.filter { !existingTitleEmbeddings.contains($0.id) }
            let missingFullEmbeddings = allPeriods.filter { !existingFullEmbeddings.contains($0.id) }

            guard !missingTitleEmbeddings.isEmpty || !missingFullEmbeddings.isEmpty else {
                print("   ✓ TimePeriods: All \(allPeriods.count) have complete embeddings (title + full)")
                return
            }

            print("   🔄 TimePeriods: Generating \(missingTitleEmbeddings.count) title-only + \(missingFullEmbeddings.count) full-context embeddings...")

            // 4. Generate embeddings
            let embeddingService = EmbeddingGenerationService(database: database)
            var titleSuccessCount = 0
            var fullSuccessCount = 0

            // Generate title-only embeddings
            for period in missingTitleEmbeddings {
                do {
                    _ = try await embeddingService.generateTimePeriodEmbedding(period: period, variant: .titleOnly)
                    titleSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate title embedding for period '\(period.timePeriodTitle ?? "Term \(period.termNumber)")': \(error)")
                }
            }

            // Generate full-context embeddings
            for period in missingFullEmbeddings {
                do {
                    _ = try await embeddingService.generateTimePeriodEmbedding(period: period, variant: .fullContext)
                    fullSuccessCount += 1
                } catch {
                    print("   ⚠️  Failed to generate full embedding for period '\(period.timePeriodTitle ?? "Term \(period.termNumber)")': \(error)")
                }
            }

            print("   ✅ TimePeriods: Generated \(titleSuccessCount) title-only + \(fullSuccessCount) full-context embeddings")

        } catch {
            print("   ❌ TimePeriods backfill failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Fetch set of entity IDs that already have embeddings for given type and variant
    ///
    /// - Parameters:
    ///   - database: Database to query
    ///   - entityType: Entity type ('goal', 'action', 'value', 'measure', 'term')
    ///   - variant: Source variant (title_only or full_context)
    /// - Returns: Set of UUIDs for entities with existing embeddings
    private static func fetchExistingEmbeddings(
        database: any DatabaseWriter,
        entityType: String,
        variant: EmbeddingSourceVariant
    ) async throws -> Set<UUID> {
        try await database.read { db in
            let sql = """
                SELECT DISTINCT entityId
                FROM semanticEmbeddings
                WHERE entityType = ? AND sourceVariant = ?
                """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [entityType, variant.rawValue])

            let uuids = rows.compactMap { row -> UUID? in
                let uuidString: String = row["entityId"]
                return UUID(uuidString: uuidString)
            }

            return Set(uuids)
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
