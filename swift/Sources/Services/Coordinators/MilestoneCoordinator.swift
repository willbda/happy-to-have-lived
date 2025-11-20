//
// MilestoneCoordinator.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Coordinates creation of Milestone entities with atomic persistence
// ARCHITECTURE: Simple two-model coordinator (Expectation + Milestone)
// PATTERN: Follows PersonalValueCoordinator pattern (no relationships to manage)
//

import Foundation
import Models
import SQLiteData

/// Coordinates creation of Milestone entities with atomic persistence.
///
/// **Architecture**: Two-model atomic transaction
/// - Creates Expectation (base, .milestone type) + Milestone (subtype) atomically
/// - No relationships to manage (simpler than Goal)
///
/// **Validation Strategy** (Two-Phase):
/// - Phase 1: Validate form data (business rules) BEFORE assembly
/// - Phase 2: Validate complete entity (referential integrity) AFTER assembly
/// - Database enforces: NOT NULL, foreign keys, CHECK constraints
///
/// **Swift 6 Concurrency Pattern**:
/// - NO @MainActor: Database I/O runs in background
/// - Sendable conformance: Safe to pass from @MainActor ViewModels
/// - Immutable state: Only `private let` properties
///
/// **Usage**:
/// ```swift
/// let coordinator = MilestoneCoordinator(database: database)
/// let milestone = try await coordinator.create(from: formData)
/// ```
public final class MilestoneCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Creates Milestone with Expectation from form data.
    /// - Parameter formData: Validated form data
    /// - Returns: Persisted Milestone with generated ID
    /// - Throws: ValidationError if validation fails, DatabaseError if constraints violated
    ///
    /// **Implementation**:
    /// 1. Validate form data (Phase 1)
    /// 2. Insert Expectation (base entity, .milestone type)
    /// 3. Insert Milestone (subtype, FK to Expectation)
    /// 4. Validate complete entity graph (Phase 2)
    /// 5. Return Milestone
    public func create(from formData: MilestoneFormData) async throws -> Milestone {
        // Phase 1: Validate form data (business rules)
        try MilestoneValidation.validateFormData(formData)

        return try await database.write { db in
            // 1. Insert Expectation (base entity with .milestone type)
            let expectation = try Expectation.insert {
                Expectation.Draft(
                    id: UUID(),
                    logTime: Date(),
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty
                        ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    expectationType: .milestone,
                    expectationImportance: formData.expectationImportance,
                    expectationUrgency: formData.expectationUrgency
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 2. Insert Milestone (subtype with FK to Expectation)
            let milestone = try Milestone.insert {
                Milestone.Draft(
                    id: UUID(),
                    expectationId: expectation.id,
                    targetDate: formData.targetDate
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // Phase 2: Validate complete entity graph (defensive check)
            try MilestoneValidation.validateComplete(expectation, milestone)

            return milestone
        }
    }

    /// Updates existing Milestone from form data.
    /// - Parameters:
    ///   - milestone: Existing Milestone to update
    ///   - formData: New form data
    /// - Returns: Updated Milestone
    /// - Throws: ValidationError if validation fails, DatabaseError if constraints violated
    ///
    /// **Implementation**:
    /// 1. Validate form data (Phase 1)
    /// 2. Update Expectation (preserve id and logTime)
    /// 3. Update Milestone (preserve id)
    /// 4. Validate complete entity graph (Phase 2)
    /// 5. Return updated Milestone
    public func update(
        milestone: Milestone,
        from formData: MilestoneFormData
    ) async throws -> Milestone {
        // Phase 1: Validate form data (business rules)
        try MilestoneValidation.validateFormData(formData)

        return try await database.write { db in
            // 1. Fetch existing expectation to preserve logTime
            guard let existingExpectation = try Expectation.find(milestone.expectationId).fetchOne(db)
            else {
                throw ValidationError.foreignKeyViolation(
                    "Expectation \(milestone.expectationId) not found")
            }

            // 2. Update Expectation (preserve id and logTime)
            let updatedExpectation = try Expectation.upsert {
                Expectation.Draft(
                    id: existingExpectation.id,
                    logTime: existingExpectation.logTime,  // Preserve original logTime
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty
                        ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    expectationType: .milestone,
                    expectationImportance: formData.expectationImportance,
                    expectationUrgency: formData.expectationUrgency
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 3. Update Milestone (preserve id)
            let updatedMilestone = try Milestone.upsert {
                Milestone.Draft(
                    id: milestone.id,  // Preserve ID
                    expectationId: updatedExpectation.id,
                    targetDate: formData.targetDate
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // Phase 2: Validate complete entity graph (defensive check)
            try MilestoneValidation.validateComplete(updatedExpectation, updatedMilestone)

            return updatedMilestone
        }
    }

    /// Deletes Milestone and its Expectation.
    /// - Parameter milestoneId: ID of milestone to delete
    /// - Throws: DatabaseError if deletion fails
    ///
    /// **Implementation**:
    /// Deletes Expectation (cascade deletes Milestone via FK constraint)
    public func delete(milestoneId: UUID) async throws {
        try await database.write { db in
            // Fetch milestone to get expectationId
            guard let milestone = try Milestone.find(milestoneId).fetchOne(db) else {
                throw ValidationError.foreignKeyViolation("Milestone \(milestoneId) not found")
            }

            // Delete Expectation (cascade deletes Milestone via FK ON DELETE CASCADE)
            if let expectation = try Expectation.find(milestone.expectationId).fetchOne(db) {
                try expectation.delete(db)
            }
        }
    }
}
