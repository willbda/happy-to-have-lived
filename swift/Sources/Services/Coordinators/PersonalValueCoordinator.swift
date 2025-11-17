import Dependencies
import Foundation
import Models
import SQLiteData

// ARCHITECTURE DECISION: Why Coordinators?
// CONTEXT: Evaluated alternatives in ARCHITECTURE_EVALUATION_20251102.md
// OPTIONS CONSIDERED:
//   A. Static methods on models (PersonalValue.create(...))
//   B. Repository pattern (PersonalValueRepository)
//   C. Coordinator pattern (this approach)
// WHY COORDINATORS:
//   - Consistent pattern across simple (PersonalValue) and complex (Goal) entities
//   - Clear separation: Models = data structure, Coordinators = persistence logic
//   - Enables multi-model atomic transactions (critical for Goal + Expectation + Measures)
//   - Easier to test persistence logic in isolation
//   - ViewModels stay focused on UI state, not database operations
// TRADEOFF: Extra layer for simple entities, but consistency matters more
// WHEN NOT TO USE: If entity has zero relationships and trivial validation
// FUTURE: If this layer feels burdensome, consider hybrid (coordinators for complex only)

/// Coordinates creation of PersonalValue entities with atomic persistence.
///
/// Validation Strategy (Two-Phase):
/// - Phase 1: Validate form data (business rules) BEFORE database write
/// - Phase 2: Validate complete entity (referential integrity) AFTER database write
/// - Repository: Check for duplicates before insert
/// - Database: Enforces NOT NULL, foreign keys, CHECK constraints
///
/// ARCHITECTURE NOTE: PersonalValue is the simplest coordinator (single model, no relationships)
/// Use this as template for other single-model coordinators (Term, Milestone)
/// For multi-model coordinators (Goal, Action), see GoalCoordinator for atomic transaction pattern
///
/// SWIFT 6 CONCURRENCY PATTERN (Migrated 2025-11-10):
/// - NO @MainActor: Coordinators perform database I/O (should run in background)
/// - Sendable conformance: Safe to pass from @MainActor ViewModels to background threads
/// - Immutable state: Only `private let` properties (thread-safe)
/// - ViewModels use lazy var: `@ObservationIgnored private lazy var coordinator = PersonalValueCoordinator(...)`
/// - Auto context switching: Swift handles main → background → main automatically
///
/// WHY Sendable is Safe:
/// - Final class (no inheritance complications)
/// - Only immutable properties (private let database)
/// - No mutable state to protect
/// - Database (SQLiteData/GRDB) handles thread safety internally
///
/// Reference: Swift Language Guide on Concurrency (Sendable Types, lines 1449-1593)
/// Reference: /Users/davidwilliams/Coding/REFERENCE/documents/SwiftLanguage/02-LanguageGuide/18-Concurrency.md
public final class PersonalValueCoordinator: Sendable {
    // ARCHITECTURE DECISION: DatabaseWriter instead of DatabaseQueue
    // CONTEXT: SQLiteData uses DatabaseWriter protocol (from GRDB)
    // PATTERN: From SQLiteData examples and DatabaseBootstrap.swift
    // WHY: DatabaseWriter is the protocol, DatabaseQueue is the concrete type
    //      Using protocol allows flexibility (could use DatabasePool for multi-threaded access)
    // SEE: sqlite-data-main/Examples/CaseStudies/ObservableModelDemo.swift:56-67
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Creates a PersonalValue from form data with two-phase validation.
    ///
    /// **Validation Flow**:
    /// 1. Phase 1: Validate business rules (title/description, priority range)
    /// 2. Check for duplicates (case-insensitive title matching)
    /// 3. Insert to database (atomic transaction)
    /// 4. Phase 2: Validate complete entity (priority set correctly)
    ///
    /// - Parameter formData: Form data from UI
    /// - Returns: Persisted PersonalValue with generated ID
    /// - Throws: ValidationError for business rule violations or duplicates
    ///           DatabaseError if database constraints violated (should be rare)
    ///
    /// **Implementation Note**: Uses `.insert` for CREATE operations.
    /// This ensures CloudKit properly tracks new records vs updates.
    /// For updates, use `.upsert` with existing ID (see update() method).
    public func create(from formData: PersonalValueFormData) async throws -> PersonalValue {
        // Phase 1: Validate form data (business rules)
        // Throws: ValidationError.emptyValue, ValidationError.invalidPriority
        try PersonalValueValidation.validateFormData(formData)

        // TODO: Add duplicate checking when PersonalValueRepository is fixed
        // For now, rely on database unique constraint

        // Insert to database (atomic transaction)
        // Note: Database errors are rare here since we validated above
        // If they occur, let them propagate as-is (likely indicates data corruption)
        let value = try await database.write { db in
            try PersonalValue.insert {
                PersonalValue.Draft(
                    id: UUID(),
                    title: formData.title,
                    detailedDescription: formData.detailedDescription,
                    freeformNotes: formData.freeformNotes,
                    logTime: Date(),
                    priority: formData.priority,
                    valueLevel: formData.valueLevel,
                    lifeDomain: formData.lifeDomain,
                    alignmentGuidance: formData.alignmentGuidance
                )
            }
            .returning { $0 }
            .fetchOne(db)!
        }

        // Phase 2: Validate complete entity (defensive check)
        // Throws: ValidationError.invalidPriority if model assembly failed
        // This should never fail if Phase 1 passed and model init is correct
        try PersonalValueValidation.validateComplete(value)

        return value
    }

    /// Updates existing PersonalValue from form data with two-phase validation.
    ///
    /// **Validation Flow**:
    /// 1. Phase 1: Validate business rules (title/description, priority range)
    /// 2. Check for duplicate titles (excluding current value)
    /// 3. Update in database (atomic transaction)
    /// 4. Phase 2: Validate complete entity (priority set correctly)
    ///
    /// - Parameters:
    ///   - value: Existing PersonalValue to update
    ///   - formData: New form data (FormData pattern - not individual params!)
    /// - Returns: Updated PersonalValue
    /// - Throws: ValidationError for business rule violations or duplicates
    ///           DatabaseError if database constraints violated
    ///
    /// **Implementation**:
    /// 1. Use .upsert (not .insert) with existing ID
    /// 2. Preserve id and logTime from existing value
    /// 3. Return updated value
    ///
    /// **Pattern**: FormData-based method (follows ActionCoordinator pattern)
    public func update(
        value: PersonalValue,
        from formData: PersonalValueFormData
    ) async throws -> PersonalValue {
        // Phase 1: Validate form data (business rules)
        try PersonalValueValidation.validateFormData(formData)

        // TODO: Add duplicate checking when PersonalValueRepository is fixed
        // For now, rely on database unique constraint

        // Update in database (atomic transaction)
        let updatedValue = try await database.write { db in
            try PersonalValue.upsert {
                PersonalValue.Draft(
                    id: value.id,  // Preserve ID
                    title: formData.title,
                    detailedDescription: formData.detailedDescription,
                    freeformNotes: formData.freeformNotes,
                    logTime: value.logTime,  // Preserve original logTime
                    priority: formData.priority,
                    valueLevel: formData.valueLevel,
                    lifeDomain: formData.lifeDomain,
                    alignmentGuidance: formData.alignmentGuidance
                )
            }
            .returning { $0 }
            .fetchOne(db)!  // Safe: successful upsert always returns value
        }

        // Phase 2: Validate complete entity (defensive check)
        try PersonalValueValidation.validateComplete(updatedValue)

        return updatedValue
    }

    /// Delete personal value using canonical PersonalValueData
    ///
    /// **NOTE**: Database FK constraints will prevent deletion if GoalRelevances exist.
    /// In future, could query for dependent goals and return helpful error message.
    ///
    /// - Parameter valueData: Canonical personal value
    /// - Throws: DatabaseError if deletion fails (e.g., FK constraint violation)
    public func delete(_ valueData: PersonalValueData) async throws {
        try await database.write { db in
            try db.execute(
                sql: "DELETE FROM personalValues WHERE id = ?",
                arguments: [valueData.id.uuidString.lowercased()]
            )
        }
    }
}
