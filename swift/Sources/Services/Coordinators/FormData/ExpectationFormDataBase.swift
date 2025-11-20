//
// ExpectationFormDataBase.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Protocol for shared expectation fields across Goal, Milestone, Obligation FormData
// PATTERN: DRY principle - prevents duplicating expectation fields 3x
// USAGE: Implement by GoalFormData, MilestoneFormData, ObligationFormData
//

import Foundation

/// Base protocol for all expectation-based form data.
///
/// **Purpose**: Defines common fields inherited from Expectation abstraction layer.
/// All expectation subtypes (Goal, Milestone, Obligation) share these base fields.
///
/// **Pattern**: Protocol with extension for shared validation logic
/// - Implementing types: GoalFormData, MilestoneFormData, ObligationFormData
/// - Eliminates duplicate field declarations across 3 FormData types
/// - Provides shared validation via protocol extension
///
/// **Usage**:
/// ```swift
/// public struct MilestoneFormData: ExpectationFormDataBase {
///     public var title: String = ""
///     public var detailedDescription: String = ""
///     // ... other ExpectationFormDataBase fields ...
///
///     // Milestone-specific fields
///     public var targetDate: Date = Date()
/// }
/// ```
public protocol ExpectationFormDataBase: Sendable {
    // MARK: - Expectation Base Fields

    /// Title of the expectation (goal/milestone/obligation)
    var title: String { get set }

    /// Detailed description of what this expectation involves
    var detailedDescription: String { get set }

    /// Freeform notes for additional context
    var freeformNotes: String { get set }

    /// Importance rating (1-10, where 10 = most important)
    var expectationImportance: Int { get set }

    /// Urgency rating (1-10, where 10 = most urgent)
    var expectationUrgency: Int { get set }
}

// MARK: - Shared Validation

extension ExpectationFormDataBase {
    /// Validates common expectation fields (Phase 1 validation).
    ///
    /// **Validation Rules**:
    /// 1. Title: Required, non-empty after trimming whitespace
    /// 2. Importance: Must be in range 1-10
    /// 3. Urgency: Must be in range 1-10
    ///
    /// **Usage**:
    /// ```swift
    /// func validateFormData(_ formData: MilestoneFormData) throws {
    ///     try formData.validateExpectationFields()
    ///     // ... additional milestone-specific validation ...
    /// }
    /// ```
    ///
    /// - Throws: ValidationError.missingRequiredField if title empty
    ///           ValidationError.invalidInput if importance/urgency out of range
    public func validateExpectationFields() throws {
        // Title required
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingRequiredField("Title is required")
        }

        // Importance range validation
        guard (1...10).contains(expectationImportance) else {
            throw ValidationError.invalidPriority(
                "Importance must be between 1 and 10 (received: \(expectationImportance))"
            )
        }

        // Urgency range validation
        guard (1...10).contains(expectationUrgency) else {
            throw ValidationError.invalidPriority(
                "Urgency must be between 1 and 10 (received: \(expectationUrgency))"
            )
        }
    }
}
