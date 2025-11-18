//
// MeasureCoordinator.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE: Coordinate Measure entity persistence with duplicate prevention
// PATTERN: Simplest coordinator pattern (parallel to PersonalValueCoordinator)
//
// ARCHITECTURE NOTE:
// Measure is Abstraction Layer catalog entity with NO relationships.
// - No multi-model transactions needed (unlike GoalCoordinator)
// - Primary responsibility: Duplicate prevention via repository.exists()
// - Secondary responsibility: Two-phase validation pattern
//
// SWIFT 6 CONCURRENCY PATTERN:
// - NO @MainActor: Database I/O runs in background
// - Sendable conformance: Safe to pass from @MainActor ViewModels
// - Immutable state: Only `private let` properties
// - Auto context switching: Swift handles main → background → main
//
// DUPLICATE PREVENTION STRATEGY:
// - Compound uniqueness: (unit, measureType) pair defines uniqueness
// - Case-insensitive matching: repository.exists() uses LOWER()
// - Example: Prevent duplicate ("km", "distance")
// - Example: Allow ("km", "distance") and ("km/h", "speed") as distinct
//
// ONTOLOGICAL DISTINCTION:
// - MeasureCoordinator = Manage catalog of measurement units
// - GoalCoordinator creates ExpectationMeasure (goal targets using measures)
//

import Dependencies
import Foundation
import Models
import SQLiteData

/// Coordinates creation of Measure entities with duplicate prevention.
///
/// **Validation Strategy** (Two-Phase):
/// - Phase 1: Validate form data (business rules) BEFORE database write
/// - Phase 2: Validate complete entity (referential integrity) AFTER database write
/// - Repository: Check for duplicates before insert (compound key: unit + measureType)
/// - Database: Enforces NOT NULL, CHECK constraints
///
/// **Usage Pattern**:
/// ```swift
/// let coordinator = MeasureCoordinator(database: database)
/// let measure = try await coordinator.create(from: formData)
/// ```
///
/// **ViewModels** should use lazy repository pattern:
/// ```swift
/// @ObservationIgnored
/// private lazy var coordinator: MeasureCoordinator = {
///     MeasureCoordinator(database: database)
/// }()
/// ```
public final class MeasureCoordinator: Sendable {
    private let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Get existing measure or create new one (idempotent pattern for coordinator composition).
    ///
    /// **Use Case**: Called by GoalCoordinator/ActionCoordinator during entity creation
    /// to ensure measures exist before creating ExpectationMeasure/MeasuredAction records.
    ///
    /// **Pattern**: Get-or-create (idempotent)
    /// 1. Check if measure exists (compound key: unit + measureType)
    /// 2. If exists → return existing measure
    /// 3. If not → create new measure with minimal FormData
    ///
    /// **Example** (GoalCoordinator calling MeasureCoordinator):
    /// ```swift
    /// // User creates goal: "Run 120 km in 10 weeks"
    /// let measureCoordinator = MeasureCoordinator(database: database)
    /// let kmMeasure = try await measureCoordinator.getOrCreate(
    ///     unit: "km",
    ///     measureType: "distance"
    /// )
    /// // Returns existing "km" measure OR creates new one if doesn't exist
    /// ```
    ///
    /// - Parameters:
    ///   - unit: Measurement unit (e.g., "km", "hours", "occasions")
    ///   - measureType: Type of measurement (e.g., "distance", "time", "count")
    ///   - title: Optional custom title (defaults to capitalized unit)
    ///   - detailedDescription: Optional description
    ///   - freeformNotes: Optional notes
    ///   - canonicalUnit: Optional canonical unit for conversions
    ///   - conversionFactor: Optional conversion factor
    /// - Returns: Existing or newly created Measure
    /// - Throws: ValidationError if creation fails (but NOT if duplicate found - that returns existing)
    ///
    public func getOrCreate(
        unit: String,
        measureType: String,
        title: String? = nil,
        detailedDescription: String? = nil,
        freeformNotes: String? = nil,
        canonicalUnit: String? = nil,
        conversionFactor: Double? = nil
    ) async throws -> Measure {
        let repository = MeasureRepository(database: database)

        // Try to find existing measure (case-insensitive compound key)
        if try await repository.exists(unit: unit, measureType: measureType) {
            let existing = try await repository.fetchAll()
            if let match = existing.first(where: {
                $0.unit.lowercased() == unit.lowercased()
                    && $0.measureType.lowercased() == measureType.lowercased()
            }) {
                // Return existing measure (idempotent - safe to call multiple times)
                // Fetch actual Measure model from database
                return try await database.read { db in
                    try Measure.find(match.id).fetchOne(db)!
                }
            }
        }

        // Create new measure (minimal FormData with sensible defaults)
        let formData = MeasureFormData(
            title: title ?? unit.capitalized,  // Default: "km" → "Km"
            unit: unit,
            measureType: measureType,
            detailedDescription: detailedDescription,
            freeformNotes: freeformNotes,
            canonicalUnit: canonicalUnit,
            conversionFactor: conversionFactor
        )

        return try await create(from: formData)
    }

    /// Creates a Measure from form data with duplicate prevention.
    ///
    /// **Validation Flow**:
    /// 1. Phase 1: Validate business rules (title, unit, measureType required)
    /// 2. Check for duplicates (compound key: unit + measureType, case-insensitive)
    /// 3. Insert to database (atomic transaction)
    /// 4. Phase 2: Validate complete entity (defensive check)
    ///
    /// **Duplicate Prevention**:
    /// - Uses MeasureRepository.exists(unit:, measureType:)
    /// - Case-insensitive matching (LOWER() in SQL)
    /// - Compound uniqueness: ("km", "distance") ≠ ("km/h", "speed")
    ///
    /// - Parameter formData: Form data from UI
    /// - Returns: Persisted Measure with generated ID
    /// - Throws: ValidationError.duplicateRecord if (unit, measureType) exists
    ///           ValidationError.emptyField if required fields missing
    ///           DatabaseError if database constraints violated (rare)
    ///
    /// **Implementation Note**: Uses `.insert` for CREATE operations.
    /// This ensures CloudKit properly tracks new records vs updates.
    /// For updates, use `.upsert` with existing ID (see update() method).
    public func create(from formData: MeasureFormData) async throws -> Measure {
        // Phase 1: Validate form data (business rules)
        try validateFormData(formData)

        // Check for duplicates (compound key: unit + measureType)
        let repository = MeasureRepository(database: database)
        if try await repository.exists(unit: formData.unit, measureType: formData.measureType) {
            throw ValidationError.duplicateRecord(
                "A measure with unit '\(formData.unit)' and type '\(formData.measureType)' already exists"
            )
        }

        // Insert to database (atomic transaction)
        let measure = try await database.write { db in
            try Measure.insert {
                Measure.Draft(
                    id: UUID(),
                    logTime: Date(),
                    title: formData.title,
                    detailedDescription: formData.detailedDescription,
                    freeformNotes: formData.freeformNotes,
                    unit: formData.unit,
                    measureType: formData.measureType,
                    canonicalUnit: formData.canonicalUnit,
                    conversionFactor: formData.conversionFactor
                )
            }
            .returning { $0 }
            .fetchOne(db)!
        }

        // Phase 2: Validate complete entity (defensive check)
        try validateComplete(measure)

        return measure
    }

    /// Updates existing Measure from form data with duplicate prevention.
    ///
    /// **Validation Flow**:
    /// 1. Phase 1: Validate business rules (title, unit, measureType required)
    /// 2. Check for duplicates (excluding current measure)
    /// 3. Update in database (atomic transaction)
    /// 4. Phase 2: Validate complete entity (defensive check)
    ///
    /// **Duplicate Prevention**:
    /// - Same as create(), but excludes current measure from duplicate check
    /// - Allows updating title/description without triggering duplicate error
    ///
    /// - Parameters:
    ///   - measure: Existing Measure to update
    ///   - formData: New form data
    /// - Returns: Updated Measure
    /// - Throws: ValidationError.duplicateRecord if (unit, measureType) exists on different measure
    ///           ValidationError.emptyField if required fields missing
    ///           DatabaseError if database constraints violated
    ///
    /// **Implementation**:
    /// 1. Use .upsert (not .insert) with existing ID
    /// 2. Preserve id and logTime from existing measure
    /// 3. Return updated measure
    public func update(
        measure: Measure,
        from formData: MeasureFormData
    ) async throws -> Measure {
        // Phase 1: Validate form data (business rules)
        try validateFormData(formData)

        // Check for duplicates (excluding current measure)
        let repository = MeasureRepository(database: database)
        if try await repository.exists(unit: formData.unit, measureType: formData.measureType) {
            // Check if duplicate is NOT the current measure
            let existing = try await repository.fetchAll()
            let duplicates = existing.filter {
                $0.unit.lowercased() == formData.unit.lowercased()
                    && $0.measureType.lowercased() == formData.measureType.lowercased()
                    && $0.id != measure.id
            }

            if !duplicates.isEmpty {
                throw ValidationError.duplicateRecord(
                    "A measure with unit '\(formData.unit)' and type '\(formData.measureType)' already exists"
                )
            }
        }

        // Update in database (atomic transaction)
        let updatedMeasure = try await database.write { db in
            try Measure.upsert {
                Measure.Draft(
                    id: measure.id,  // Preserve ID
                    logTime: measure.logTime,  // Preserve original logTime
                    title: formData.title,
                    detailedDescription: formData.detailedDescription,
                    freeformNotes: formData.freeformNotes,
                    unit: formData.unit,
                    measureType: formData.measureType,
                    canonicalUnit: formData.canonicalUnit,
                    conversionFactor: formData.conversionFactor
                )
            }
            .returning { $0 }
            .fetchOne(db)!  // Safe: successful upsert always returns value
        }

        // Phase 2: Validate complete entity (defensive check)
        try validateComplete(updatedMeasure)

        return updatedMeasure
    }

    /// Delete measure using canonical MeasureData
    ///
    /// **IMPORTANT**: Database FK constraints will prevent deletion if:
    /// - measuredActions reference this measure
    /// - expectationMeasures reference this measure
    ///
    /// In future, could query for dependent records and return helpful error message.
    ///
    /// - Parameter measureData: Canonical measure data
    /// - Throws: DatabaseError if deletion fails (e.g., FK constraint violation)
    public func delete(_ measureData: MeasureData) async throws {
        try await database.write { db in
            try db.execute(
                sql: "DELETE FROM measures WHERE id = ?",
                arguments: [measureData.id.uuidString.lowercased()]
            )
        }
    }

    // MARK: - Private Validation

    /// Phase 1: Validate form data (business rules)
    ///
    /// **Requirements**:
    /// - title: Non-empty string
    /// - unit: Non-empty string
    /// - measureType: Non-empty string
    /// - conversionFactor: If canonicalUnit set, conversionFactor must be > 0
    ///
    /// - Throws: ValidationError.emptyField if required fields missing
    ///           ValidationError.invalidInput if conversion logic inconsistent
    private func validateFormData(_ formData: MeasureFormData) throws {
        // Title required
        guard !formData.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField("Measure title is required")
        }

        // Unit required
        guard !formData.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField("Measure unit is required")
        }

        // MeasureType required
        guard !formData.measureType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField("Measure type is required")
        }

        // Conversion logic consistency
        if let canonicalUnit = formData.canonicalUnit {
            guard let conversionFactor = formData.conversionFactor, conversionFactor > 0 else {
                throw ValidationError.databaseConstraint(
                    "Conversion factor must be > 0 when canonical unit is specified"
                )
            }
        }
    }

    /// Phase 2: Validate complete entity (defensive check)
    ///
    /// **Requirements**:
    /// - Same as Phase 1 (title, unit, measureType non-empty)
    /// - Conversion factor > 0 if canonical unit set
    ///
    /// This should never fail if Phase 1 passed and model init is correct.
    ///
    /// - Throws: ValidationError if entity is invalid
    private func validateComplete(_ measure: Measure) throws {
        // Title required
        guard let title = measure.title,
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ValidationError.missingRequiredField("Measure title is required")
        }

        // Unit required
        guard !measure.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField("Measure unit is required")
        }

        // MeasureType required
        guard !measure.measureType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField("Measure type is required")
        }

        // Conversion logic consistency
        if let canonicalUnit = measure.canonicalUnit, !canonicalUnit.isEmpty {
            guard let conversionFactor = measure.conversionFactor, conversionFactor > 0 else {
                throw ValidationError.databaseConstraint(
                    "Conversion factor must be > 0 when canonical unit is specified"
                )
            }
        }
    }
}
