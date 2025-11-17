import Dependencies
import Foundation
import Models
import Observation
import SQLiteData
import Services
import SwiftUI

// ARCHITECTURE DECISION: Why @Observable instead of ObservableObject?
// CONTEXT: Swift 5.9+ introduced @Observable macro as modern replacement for ObservableObject
// BENEFITS:
//   - No @Published needed - all properties auto-tracked
//   - Better performance (fine-grained observation)
//   - Cleaner syntax (less boilerplate)
// TRADEOFF: @Observable only works on classes, not structs
//   Our models (PersonalValue) are structs (required by SQLiteData @Table macro)
//   So ViewModels serve as @Observable wrappers for struct models
// SEE: ARCHITECTURE_EVALUATION_20251102.md for full analysis
//
// ARCHITECTURE DECISION: @Observable + @Dependency Pattern
// PATTERN: Based on SQLiteData's ObservableModelDemo example
// KEY: Use @ObservationIgnored on @Dependency properties
// WHY: Prevents @Observable macro from trying to track dependency changes
// SEE: sqlite-data-main/Examples/CaseStudies/ObservableModelDemo.swift

@Observable
@MainActor
public final class PersonalValuesFormViewModel {
    public var isSaving: Bool = false
    public var errorMessage: String?

    // ARCHITECTURE DECISION: @ObservationIgnored + @Dependency
    // CONTEXT: @Observable macro conflicts with @Dependency unless ignored
    // PATTERN: From SQLiteData's ObservableModelDemo.swift:56-57
    // SOLUTION: Mark @Dependency with @ObservationIgnored
    // RESULT: Database dependency works, but changes aren't tracked (which is fine)
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    // ARCHITECTURE DECISION: Lazy stored property with @ObservationIgnored
    // CONTEXT: Swift 6 strict concurrency - coordinators are now non-isolated
    // PATTERN: Use lazy var with @ObservationIgnored for multi-method coordinator usage
    // WHY LAZY: Coordinator used in multiple methods (save, update, delete)
    // WHY @ObservationIgnored: Coordinators are stateless services, no observable state
    // RESULT: Coordinator created once on first use, safe across all async methods
    @ObservationIgnored
    private lazy var coordinator: PersonalValueCoordinator = {
        PersonalValueCoordinator(database: database)
    }()

    public init() {}

    // ARCHITECTURE DECISION: Individual parameters vs FormData object?
    // CURRENT: Individual parameters (mirrors PersonalValueFormData fields)
    // ALTERNATIVE: Accept `PersonalValueFormData` directly
    // WHY INDIVIDUAL PARAMS:
    //   - More ergonomic for SwiftUI forms (no wrapper object)
    //   - Clear what's required vs optional
    //   - Better autocomplete in Xcode
    // TRADEOFF: Duplicates field definitions (two places to update when adding fields)
    // FUTURE: If fields exceed 7-8 parameters, consider switching to PersonalValueFormData object
    /// Creates new PersonalValue from form data.
    /// - Parameter formData: Validated form data
    /// - Returns: Created PersonalValue
    /// - Throws: CoordinatorError or database errors
    ///
    /// PATTERN: FormData-based method (clean, template-ready)
    public func save(from formData: PersonalValueFormData) async throws -> PersonalValue {
        isSaving = true
        defer { isSaving = false }

        do {
            let value = try await coordinator.create(from: formData)
            errorMessage = nil
            return value
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Creates new PersonalValue from individual parameters.
    /// - Parameters: Individual form fields
    /// - Returns: Created PersonalValue
    /// - Throws: CoordinatorError or database errors
    ///
    /// NOTE: Legacy method - prefer save(from:) for consistency
    public func save(
        title: String,
        level: ValueLevel,
        priority: Int,
        description: String? = nil,
        notes: String? = nil,
        lifeDomain: String? = nil,
        alignmentGuidance: String? = nil
    ) async throws -> PersonalValue {
        let formData = PersonalValueFormData(
            title: title,
            detailedDescription: description,
            freeformNotes: notes,
            valueLevel: level,
            priority: priority,
            lifeDomain: lifeDomain,
            alignmentGuidance: alignmentGuidance
        )

        return try await save(from: formData)
    }

    /// Updates existing PersonalValue from form data.
    /// - Parameters:
    ///   - valueData: Existing PersonalValueData (canonical type)
    ///   - formData: New form data
    /// - Returns: Updated PersonalValue
    /// - Throws: CoordinatorError or database errors
    ///
    /// PATTERN: FormData-based method (establishes pattern for template)
    public func update(
        valueData: PersonalValueData,
        from formData: PersonalValueFormData
    ) async throws -> PersonalValue {
        isSaving = true
        defer { isSaving = false }

        do {
            // Reconstruct PersonalValue entity from PersonalValueData
            let value = PersonalValue(
                title: valueData.title,
                detailedDescription: valueData.detailedDescription,
                freeformNotes: valueData.freeformNotes,
                priority: valueData.priority,
                valueLevel: ValueLevel(rawValue: valueData.valueLevel) ?? .general,
                lifeDomain: valueData.lifeDomain,
                alignmentGuidance: valueData.alignmentGuidance,
                logTime: valueData.logTime,
                id: valueData.id
            )

            let updatedValue = try await coordinator.update(value: value, from: formData)
            errorMessage = nil
            return updatedValue
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Deletes PersonalValue.
    /// - Parameter valueData: Canonical personal value data to delete
    /// - Throws: Database errors if constraints violated
    public func delete(valueData: PersonalValueData) async throws {
        isSaving = true
        defer { isSaving = false }

        do {
            try await coordinator.delete(valueData)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
