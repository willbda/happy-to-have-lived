//
// ActionCoordinator.swift
// Written by Claude Code on 2025-11-02
//
// PURPOSE: Coordinates creation of Action entities with measurements and goal contributions
// ARCHITECTURE: Multi-model atomic transactions (Action + MeasuredAction[] + ActionGoalContribution[])
//

import Foundation
import Models
import SQLiteData

/// Coordinates creation of Action entities with atomic persistence.
///
/// ARCHITECTURE DECISION: Multi-model coordinator pattern
/// - Coordinator works with Action (abstraction) + 2 relationship tables
/// - Creates Action + MeasuredAction[] + ActionGoalContribution[] atomically
/// - Validates that referenced Measures and Goals exist before insert
///
/// Validation Strategy (Two-Phase):
/// - Phase 1: Validate form data (business rules) BEFORE assembly
/// - Phase 2: Validate complete entity (referential integrity) AFTER assembly
/// - FK existence checked before insert (Measures, Goals)
/// - Database enforces: NOT NULL, foreign keys, CHECK constraints
///
/// PATTERN: Three-model atomic transaction (Action + MeasuredAction[] + ActionGoalContribution[])
/// More complex than: TimePeriod (1:1), simpler than: Goal (5+ models)
public final class ActionCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Creates Action with measurements and goal contributions from form data.
    /// - Parameter formData: Validated form data with measurements and goal IDs
    /// - Returns: Persisted Action with generated ID
    /// - Throws: Database errors if constraints violated or referenced entities don't exist
    ///
    /// IMPLEMENTATION:
    /// 1. Validate measureIds exist in Measures table
    /// 2. Validate goalIds exist in Goals table (if any)
    /// 3. Insert Action (using .insert for CREATE, not .upsert)
    /// 4. Insert MeasuredAction records for each measurement
    /// 5. Insert ActionGoalContribution records for each goal
    /// 6. Return Action (caller can access relationships via queries)
    public func create(from formData: ActionFormData) async throws -> Action {
        // Phase 1: Validate form data (business rules)
        // Throws: ValidationError.emptyAction, ValidationError.invalidDateRange, etc.
        try ActionValidation.validateFormData(formData)

        return try await database.write { db in
            // Validate measureIds exist (if any measurements provided)
            for measurement in formData.measurements where measurement.measureId != nil {
                let measureExists = try Measure.find(measurement.measureId!).fetchOne(db) != nil
                guard measureExists else {
                    throw ValidationError.invalidMeasure("Measure \(measurement.measureId!) not found")
                }
            }

            // Validate goalIds exist (if any contributions provided)
            for goalId in formData.goalContributions {
                let goalExists = try Goal.find(goalId).fetchOne(db) != nil
                guard goalExists else {
                    throw ValidationError.invalidGoal("Goal \(goalId) not found")
                }
            }

            // 3. Insert Action (using .insert for CREATE)
            let action = try Action.insert {
                Action.Draft(
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    durationMinutes: formData.durationMinutes > 0 ? formData.durationMinutes : nil,
                    startTime: formData.startTime,
                    logTime: Date(),
                    id: UUID()
                )
            }
            .returning { $0 }
            .fetchOne(db)!  // Safe: successful insert always returns value

            // 4. Insert MeasuredAction records for each valid measurement
            for measurement in formData.measurements where measurement.isValid {
                try MeasuredAction.insert {
                    MeasuredAction.Draft(
                        id: UUID(),
                        actionId: action.id,
                        measureId: measurement.measureId!,  // Already validated above
                        value: measurement.value,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // 5. Insert ActionGoalContribution records for each goal
            for goalId in formData.goalContributions {
                try ActionGoalContribution.insert {
                    ActionGoalContribution.Draft(
                        id: UUID(),
                        actionId: action.id,
                        goalId: goalId,
                        contributionAmount: nil,  // Can be calculated later by service
                        measureId: nil,  // Can be set when calculating progress
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // Phase 2: Validate complete entity graph (referential integrity)
            // Build the arrays for validation
            let measurements = formData.measurements.compactMap { measurement -> MeasuredAction? in
                guard let measureId = measurement.measureId else { return nil }
                return MeasuredAction(
                    actionId: action.id,
                    measureId: measureId,
                    value: measurement.value,
                    createdAt: Date(),
                    id: UUID()
                )
            }

            let contributions = formData.goalContributions.map { goalId in
                ActionGoalContribution(
                    actionId: action.id,
                    goalId: goalId,
                    contributionAmount: nil,
                    measureId: nil,
                    createdAt: Date(),
                    id: UUID()
                )
            }

            try ActionValidation.validateComplete(action, measurements, contributions)

            // 6. Return Action (caller accesses relationships via ActionsQuery)
            return action
        }
    }

    /// Updates existing Action with measurements and goal contributions from form data.
    /// - Parameters:
    ///   - action: Existing Action to update
    ///   - measurements: Existing MeasuredAction records to replace
    ///   - contributions: Existing ActionGoalContribution records to replace
    ///   - formData: New form data
    /// - Returns: Updated Action
    /// - Throws: Database errors if constraints violated
    ///
    /// IMPLEMENTATION:
    /// 1. Update Action (preserves id and logTime)
    /// 2. Delete old MeasuredAction records
    /// 3. Insert new MeasuredAction records from formData
    /// 4. Delete old ActionGoalContribution records
    /// 5. Insert new ActionGoalContribution records from formData
    /// 6. Return updated Action
    ///
    /// NOTE: This is a replace strategy (delete + insert) rather than diff strategy.
    /// Simpler for MVP, can optimize later if performance becomes an issue.
    public func update(
        action: Action,
        measurements: [MeasuredAction],
        contributions: [ActionGoalContribution],
        from formData: ActionFormData
    ) async throws -> Action {
        // Phase 1: Validate form data (business rules)
        try ActionValidation.validateFormData(formData)

        return try await database.write { db in
            // 1. Validate new measureIds exist (if any)
            for measurement in formData.measurements where measurement.measureId != nil {
                let measureExists = try Measure.find(measurement.measureId!).fetchOne(db) != nil
                guard measureExists else {
                    throw ValidationError.invalidMeasure("Measure \(measurement.measureId!) not found")
                }
            }

            // 2. Validate new goalIds exist (if any)
            for goalId in formData.goalContributions {
                let goalExists = try Goal.find(goalId).fetchOne(db) != nil
                guard goalExists else {
                    throw ValidationError.invalidGoal("Goal \(goalId) not found")
                }
            }

            // 3. Update Action (preserve id and logTime)
            let updatedAction = try Action.upsert {
                Action.Draft(
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    durationMinutes: formData.durationMinutes > 0 ? formData.durationMinutes : nil,
                    startTime: formData.startTime,
                    logTime: action.logTime,  // Preserve original logTime
                    id: action.id  // Preserve ID
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 4. Delete old MeasuredAction records
            for measurement in measurements {
                try MeasuredAction.delete(measurement).execute(db)
            }

            // 5. Insert new MeasuredAction records from formData
            for measurement in formData.measurements where measurement.isValid {
                try MeasuredAction.insert {
                    MeasuredAction.Draft(
                        id: UUID(),  // New ID for new record
                        actionId: updatedAction.id,
                        measureId: measurement.measureId!,
                        value: measurement.value,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // 6. Delete old ActionGoalContribution records
            for contribution in contributions {
                try ActionGoalContribution.delete(contribution).execute(db)
            }

            // 7. Insert new ActionGoalContribution records from formData
            for goalId in formData.goalContributions {
                try ActionGoalContribution.insert {
                    ActionGoalContribution.Draft(
                        id: UUID(),  // New ID for new record
                        actionId: updatedAction.id,
                        goalId: goalId,
                        contributionAmount: nil,
                        measureId: nil,
                        createdAt: Date()
                    )
                }
                .execute(db)
            }

            // Phase 2: Validate complete entity graph
            let newMeasurements = formData.measurements.compactMap { measurement -> MeasuredAction? in
                guard let measureId = measurement.measureId else { return nil }
                return MeasuredAction(
                    actionId: updatedAction.id,
                    measureId: measureId,
                    value: measurement.value,
                    createdAt: Date(),
                    id: UUID()
                )
            }

            let newContributions = formData.goalContributions.map { goalId in
                ActionGoalContribution(
                    actionId: updatedAction.id,
                    goalId: goalId,
                    contributionAmount: nil,
                    measureId: nil,
                    createdAt: Date(),
                    id: UUID()
                )
            }

            try ActionValidation.validateComplete(updatedAction, newMeasurements, newContributions)

            return updatedAction
        }
    }

    /// Delete action and all its relationships using canonical ActionData
    ///
    /// Deletes in correct order respecting foreign key constraints:
    /// 1. MeasuredActions (FK → Action)
    /// 2. ActionGoalContributions (FK → Action)
    /// 3. Action
    ///
    /// - Parameter actionData: Canonical action with all relationships
    /// - Throws: DatabaseError if deletion fails
    public func delete(_ actionData: ActionData) async throws {
        try await database.write { db in
            // 1. Delete MeasuredActions by ID
            for measurement in actionData.measurements {
                try db.execute(
                    sql: "DELETE FROM measuredActions WHERE id = ?",
                    arguments: [measurement.id.uuidString]
                )
            }

            // 2. Delete ActionGoalContributions by ID
            for contribution in actionData.contributions {
                try db.execute(
                    sql: "DELETE FROM actionGoalContributions WHERE id = ?",
                    arguments: [contribution.id.uuidString]
                )
            }

            // 3. Delete Action by ID
            try db.execute(
                sql: "DELETE FROM actions WHERE id = ?",
                arguments: [actionData.id.uuidString]
            )
        }
    }
}
