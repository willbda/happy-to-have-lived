//
// ObligationCoordinator.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Coordinates creation of Obligation entities with atomic persistence
// ARCHITECTURE: Simple two-model coordinator (Expectation + Obligation)
// PATTERN: Follows MilestoneCoordinator pattern (no relationships to manage)
//

import Foundation
import Models
import SQLiteData

/// Coordinates creation of Obligation entities with atomic persistence.
///
/// **Architecture**: Two-model atomic transaction
/// - Creates Expectation (base, .obligation type) + Obligation (subtype) atomically
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
/// let coordinator = ObligationCoordinator(database: database)
/// let obligation = try await coordinator.create(from: formData)
/// ```
public final class ObligationCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Creates Obligation with Expectation from form data.
    /// - Parameter formData: Validated form data
    /// - Returns: Persisted Obligation with generated ID
    /// - Throws: ValidationError if validation fails, DatabaseError if constraints violated
    ///
    /// **Implementation**:
    /// 1. Validate form data (Phase 1)
    /// 2. Insert Expectation (base entity, .obligation type)
    /// 3. Insert Obligation (subtype, FK to Expectation)
    /// 4. Validate complete entity graph (Phase 2)
    /// 5. Return Obligation
    public func create(from formData: ObligationFormData) async throws -> Obligation {
        // Phase 1: Validate form data (business rules)
        try ObligationValidation.validateFormData(formData)

        return try await database.write { db in
            // 1. Insert Expectation (base entity with .obligation type)
            let expectation = try Expectation.insert {
                Expectation.Draft(
                    id: UUID(),
                    logTime: Date(),
                    title: formData.title.isEmpty ? nil : formData.title,
                    detailedDescription: formData.detailedDescription.isEmpty
                        ? nil : formData.detailedDescription,
                    freeformNotes: formData.freeformNotes.isEmpty ? nil : formData.freeformNotes,
                    expectationType: .obligation,
                    expectationImportance: formData.expectationImportance,
                    expectationUrgency: formData.expectationUrgency
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 2. Insert Obligation (subtype with FK to Expectation)
            let obligation = try Obligation.insert {
                Obligation.Draft(
                    id: UUID(),
                    expectationId: expectation.id,
                    deadline: formData.deadline,
                    requestedBy: formData.requestedBy.isEmpty ? nil : formData.requestedBy,
                    consequence: formData.consequence.isEmpty ? nil : formData.consequence
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // Phase 2: Validate complete entity graph (defensive check)
            try ObligationValidation.validateComplete(expectation, obligation)

            return obligation
        }
    }

    /// Updates existing Obligation from form data.
    /// - Parameters:
    ///   - obligation: Existing Obligation to update
    ///   - formData: New form data
    /// - Returns: Updated Obligation
    /// - Throws: ValidationError if validation fails, DatabaseError if constraints violated
    ///
    /// **Implementation**:
    /// 1. Validate form data (Phase 1)
    /// 2. Update Expectation (preserve id and logTime)
    /// 3. Update Obligation (preserve id)
    /// 4. Validate complete entity graph (Phase 2)
    /// 5. Return updated Obligation
    public func update(
        obligation: Obligation,
        from formData: ObligationFormData
    ) async throws -> Obligation {
        // Phase 1: Validate form data (business rules)
        try ObligationValidation.validateFormData(formData)

        return try await database.write { db in
            // 1. Fetch existing expectation to preserve logTime
            guard let existingExpectation = try Expectation.find(obligation.expectationId).fetchOne(db)
            else {
                throw ValidationError.foreignKeyViolation(
                    "Expectation \(obligation.expectationId) not found")
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
                    expectationType: .obligation,
                    expectationImportance: formData.expectationImportance,
                    expectationUrgency: formData.expectationUrgency
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // 3. Update Obligation (preserve id)
            let updatedObligation = try Obligation.upsert {
                Obligation.Draft(
                    id: obligation.id,  // Preserve ID
                    expectationId: updatedExpectation.id,
                    deadline: formData.deadline,
                    requestedBy: formData.requestedBy.isEmpty ? nil : formData.requestedBy,
                    consequence: formData.consequence.isEmpty ? nil : formData.consequence
                )
            }
            .returning { $0 }
            .fetchOne(db)!

            // Phase 2: Validate complete entity graph (defensive check)
            try ObligationValidation.validateComplete(updatedExpectation, updatedObligation)

            return updatedObligation
        }
    }

    /// Deletes Obligation and its Expectation.
    /// - Parameter obligationId: ID of obligation to delete
    /// - Throws: DatabaseError if deletion fails
    ///
    /// **Implementation**:
    /// Deletes Expectation (cascade deletes Obligation via FK constraint)
    public func delete(obligationId: UUID) async throws {
        try await database.write { db in
            // Fetch obligation to get expectationId
            guard let obligation = try Obligation.find(obligationId).fetchOne(db) else {
                throw ValidationError.foreignKeyViolation("Obligation \(obligationId) not found")
            }

            // Delete Expectation (cascade deletes Obligation via FK ON DELETE CASCADE)
            if let expectation = try Expectation.find(obligation.expectationId).fetchOne(db) {
                try expectation.delete(db)
            }
        }
    }
}
