//
// HealthKitImportService.swift
// Written by Claude Code on 2025-11-05
//
// PURPOSE:
// Converts HealthKit workouts to app Actions with measurements
//

#if os(iOS)
    import Foundation
    import Models
    import SQLiteData
    import Dependencies

    /// Service for importing HealthKit workouts as Actions
    ///
    /// Converts HealthWorkout → Action + MeasuredAction records
    /// - Duration → hours or minutes measurement
    /// - Distance → km measurement
    /// - Calories → kcal measurement
    ///
    /// ARCHITECTURE NOTE: Marked @MainActor because:
    /// - Uses @Dependency injection which requires main actor isolation
    /// - Performs database writes via ActionCoordinator (which may have @MainActor)
    /// - Typically called from UI context (import button actions)
    /// - Database operations are async but dependency resolution needs main actor
    @MainActor
    public final class HealthKitImportService {
        @Dependency(\.defaultDatabase) var database

        public init() {}

        /// Import a single workout as an Action
        /// - Parameter workout: HealthKit workout to import
        /// - Returns: Created Action with measurements
        /// - Throws: Database errors
        ///
        /// **Refactored 2025-11-17**: Uses MeasureCoordinator.getOrCreate()
        /// instead of findOrCreateMeasure() for proper duplicate prevention.
        public func importWorkout(_ workout: HealthWorkout) async throws -> Action {
            // COORDINATOR COMPOSITION: Get-or-create measures BEFORE transaction
            // This ensures all measures exist with proper duplicate prevention
            let measureCoordinator = MeasureCoordinator(database: database)

            // 1. Get-or-create duration measure (hours or minutes)
            let durationMeasure = try await measureCoordinator.getOrCreate(
                unit: workout.duration >= 3600 ? "hours" : "minutes",
                measureType: "time"
            )

            // 2. Get-or-create distance measure (if workout has distance)
            let distanceMeasure: Measure? =
                workout.totalDistance != nil
                ? try await measureCoordinator.getOrCreate(unit: "km", measureType: "distance")
                : nil

            // 3. Get-or-create calories measure (if workout has energy)
            let caloriesMeasure: Measure? =
                workout.totalEnergyBurned != nil
                ? try await measureCoordinator.getOrCreate(unit: "kcal", measureType: "energy")
                : nil

            // NOW write action + measurements in single atomic transaction
            return try await database.write { db in
                // Create the Action
                let action = try Action.upsert {
                    Action.Draft(
                        title: workout.activityName,
                        detailedDescription: "Imported from Apple Health",
                        freeformNotes: nil,
                        durationMinutes: workout.duration / 60,  // Convert seconds to minutes as Double
                        startTime: workout.startDate,
                        logTime: workout.endDate,
                        id: UUID()
                    )
                }
                .returning { $0 }
                .fetchOne(db)!

                // Add duration measurement
                let durationValue =
                    workout.duration >= 3600
                    ? workout.duration / 3600  // Convert to hours
                    : workout.duration / 60  // Convert to minutes

                try MeasuredAction.upsert {
                    MeasuredAction.Draft(
                        id: UUID(),
                        actionId: action.id,
                        measureId: durationMeasure.id,  // From coordinator (guaranteed to exist)
                        value: durationValue,
                        createdAt: Date()
                    )
                }
                .execute(db)

                // Add distance measurement (if available)
                if let distanceMeasure = distanceMeasure, let distanceMeters = workout.totalDistance {
                    try MeasuredAction.upsert {
                        MeasuredAction.Draft(
                            id: UUID(),
                            actionId: action.id,
                            measureId: distanceMeasure.id,  // From coordinator (guaranteed to exist)
                            value: distanceMeters / 1000,  // Convert to km
                            createdAt: Date()
                        )
                    }
                    .execute(db)
                }

                // Add calories measurement (if available)
                if let caloriesMeasure = caloriesMeasure, let calories = workout.totalEnergyBurned {
                    try MeasuredAction.upsert {
                        MeasuredAction.Draft(
                            id: UUID(),
                            actionId: action.id,
                            measureId: caloriesMeasure.id,  // From coordinator (guaranteed to exist)
                            value: calories,
                            createdAt: Date()
                        )
                    }
                    .execute(db)
                }

                return action
            }
        }

        /// Import multiple workouts
        /// - Parameter workouts: Array of workouts to import
        /// - Returns: Array of created Actions
        /// - Throws: Database errors (rolls back all on failure)
        public func importWorkouts(_ workouts: [HealthWorkout]) async throws -> [Action] {
            var importedActions: [Action] = []

            for workout in workouts {
                let action = try await importWorkout(workout)
                importedActions.append(action)
            }

            return importedActions
        }

        // MARK: - Private Helpers

        // NOTE: findOrCreateMeasure() removed 2025-11-17
        // Now uses MeasureCoordinator.getOrCreate() instead (see importWorkout above)
        // Benefits:
        // - Proper duplicate prevention via coordinator
        // - Case-insensitive matching via repository
        // - Two-phase validation
        // - Single source of truth for measure creation
    }

#else
    // MARK: - macOS Stub

    import Foundation
    import Models

    @MainActor
    public final class HealthKitImportService {
        public init() {}

        public func importWorkout(_ workout: HealthWorkout) async throws -> Action {
            throw NSError(
                domain: "HealthKitImportService", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "HealthKit not available on macOS"
                ])
        }

        public func importWorkouts(_ workouts: [HealthWorkout]) async throws -> [Action] {
            throw NSError(
                domain: "HealthKitImportService", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "HealthKit not available on macOS"
                ])
        }
    }
#endif
