//
// TimePeriodCoordinator.swift
// Written by Claude Code on 2025-11-02
//
// PURPOSE: Coordinates creation of TimePeriod entities with specializations (GoalTerm, Year, etc.)
// ARCHITECTURE: Ontologically pure - works with TimePeriod abstraction, creates appropriate specialization
//

import Foundation
import Models
import SQLiteData

/// Coordinates creation of TimePeriod entities with atomic persistence.
///
/// ARCHITECTURE DECISION: Ontological purity in data layer
/// - Coordinator works with TimePeriod (abstraction), not Term/Year (specifics)
/// - Creates TimePeriod + appropriate specialization (GoalTerm, Year, etc.) atomically
/// - Views handle user-friendly naming ("Terms", "Years") via type-specific wrappers
///
/// Validation Strategy (Two-Phase):
/// - Phase 1: Validate form data (business rules) BEFORE assembly
/// - Phase 2: Validate complete entity (referential integrity) AFTER assembly (for terms)
/// - Database enforces: NOT NULL, foreign keys, CHECK constraints, date ranges
///
/// PATTERN: Two-model atomic transaction (TimePeriod + Specialization)
/// Similar to: Goal (Expectation + Goal), but simpler (1:1 relationship)
public final class TimePeriodCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Creates TimePeriod with specialization from form data.
    /// - Parameter formData: Validated form data with specialization type
    /// - Returns: Persisted TimePeriod with generated ID
    /// - Throws: Database errors if constraints violated
    ///
    /// IMPLEMENTATION:
    /// 1. Insert TimePeriod (abstraction)
    /// 2. Insert specialization (GoalTerm, Year, etc.) with FK to TimePeriod
    /// 3. Return TimePeriod (caller can access specialization via relationship)
    public func create(from formData: TimePeriodFormData) async throws -> TimePeriod {
        // Phase 1: Validate form data if it's a term (business rules)
        if case .term(_) = formData.specialization {
            try TermValidation.validateFormData(formData)
        }

        return try await database.write { db in
            // 1. Insert TimePeriod (using .insert for CREATE, not .upsert)
            let timePeriod = try TimePeriod.insert {
                TimePeriod.Draft(
                    id: UUID(),
                    title: formData.title,
                    detailedDescription: formData.detailedDescription,
                    freeformNotes: formData.freeformNotes,
                    logTime: Date(),
                    startDate: formData.startDate,
                    endDate: formData.targetDate  // FormData uses targetDate, model uses endDate
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 2. Insert specialization based on type (using .insert for CREATE)
            switch formData.specialization {
            case .term(let number):
                // Insert GoalTerm with FK to TimePeriod
                let goalTerm = try GoalTerm.insert {
                    GoalTerm.Draft(
                        id: UUID(),
                        timePeriodId: timePeriod.id,
                        termNumber: number,
                        theme: formData.theme,  // Include theme on create
                        reflection: nil,
                        status: .planned  // Default status for new terms
                    )
                }
                .returning { $0 }
                .fetchOne(db)!

                // Phase 2: Validate complete entity graph (for terms only)
                // Note: Empty assignments array for new terms
                try TermValidation.validateComplete(timePeriod, goalTerm, [])

            case .year(let yearNumber):
                // Future: Insert Year model when created
                // For now, just create TimePeriod without specialization
                // This allows the architecture to work even without Year model
                break

            case .custom:
                // No specialization - just the TimePeriod
                break
            }

            // 3. Return TimePeriod (caller can access goalTerm via relationship if needed)
            return timePeriod
        }
    }

    /// Updates existing TimePeriod with specialization from form data.
    /// - Parameters:
    ///   - timePeriod: Existing TimePeriod to update
    ///   - goalTerm: Existing GoalTerm to update
    ///   - formData: New form data
    /// - Returns: Updated TimePeriod
    /// - Throws: Database errors if constraints violated
    ///
    /// IMPLEMENTATION:
    /// 1. Update TimePeriod (preserves id and logTime)
    /// 2. Update specialization (GoalTerm, Year, etc.)
    /// 3. Return updated TimePeriod
    public func update(
        timePeriod: TimePeriod,
        goalTerm: GoalTerm,
        from formData: TimePeriodFormData
    ) async throws -> TimePeriod {
        // Phase 1: Validate form data if it's a term
        if case .term(_) = formData.specialization {
            try TermValidation.validateFormData(formData)
        }

        return try await database.write { db in
            // 1. Update TimePeriod (preserve id and logTime)
            let updatedTimePeriod = try TimePeriod.upsert {
                TimePeriod.Draft(
                    id: timePeriod.id,  // Preserve ID
                    title: formData.title,
                    detailedDescription: formData.detailedDescription,
                    freeformNotes: formData.freeformNotes,
                    logTime: timePeriod.logTime,  // Preserve original logTime
                    startDate: formData.startDate,
                    endDate: formData.targetDate
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 2. Update specialization based on type
            switch formData.specialization {
            case .term(let number):
                let updatedGoalTerm = try GoalTerm.upsert {
                    GoalTerm.Draft(
                        id: goalTerm.id,  // Preserve ID
                        timePeriodId: updatedTimePeriod.id,
                        termNumber: number,
                        theme: formData.theme,
                        reflection: formData.reflection,
                        status: formData.status ?? goalTerm.status
                    )
                }
                .returning { $0 }
                .fetchOne(db)!

                // Phase 2: Validate complete entity graph (for terms)
                // Note: Would need to fetch assignments if we want to validate them
                // For now, assume no assignments change during term update
                try TermValidation.validateComplete(updatedTimePeriod, updatedGoalTerm, [])

            case .year(let yearNumber):
                // Future: Update Year model when created
                break

            case .custom:
                // No specialization to update
                break
            }

            return updatedTimePeriod
        }
    }

    /// Delete time period and its specialization using canonical TimePeriodData
    ///
    /// Deletes in correct order respecting foreign key constraints:
    /// 1. GoalTerm (FK → TimePeriod)
    /// 2. TimePeriod
    ///
    /// **NOTE**: This will fail if TermGoalAssignments exist (FK constraint).
    /// In future, could check for assignments and warn user first.
    ///
    /// - Parameter timePeriodData: Canonical time period with specialization
    /// - Throws: DatabaseError if deletion fails (e.g., FK constraint violation)
    public func delete(_ timePeriodData: TimePeriodData) async throws {
        try await database.write { db in
            // 1. Delete GoalTerm by ID (has FK to TimePeriod)
            try db.execute(
                sql: "DELETE FROM goalTerms WHERE id = ?",
                arguments: [timePeriodData.id.uuidString]
            )

            // 2. Delete TimePeriod by ID
            try db.execute(
                sql: "DELETE FROM timePeriods WHERE id = ?",
                arguments: [timePeriodData.timePeriodId.uuidString]
            )
        }
    }
}
