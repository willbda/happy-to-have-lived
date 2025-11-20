// ValidationError.swift
// Written by Claude Code on 2025-11-04
//
// PURPOSE:
// Defines all validation errors with user-friendly messages.
// Replaces compile-time type safety lost when using #sql macros.
//
// ARCHITECTURE POSITION:
// Foundation layer - no dependencies, used by all validators.
//
// UPSTREAM (calls this):
// - ActionValidator, GoalValidator, TermValidator, PersonalValueValidator
// - ActionCoordinator, GoalCoordinator, TermCoordinator, ValueCoordinator (catch these)
// - ViewModels (display error.userMessage to user)
//
// DOWNSTREAM (this calls):
// - None (leaf node in dependency graph)
//
// DESIGN:
// - LocalizedError protocol for SwiftUI integration
// - Each case has associated String for context
// - userMessage computed property provides user-facing text
// - Clear distinction between Layer A/B (business) vs Layer C (database) errors
//
// ERROR CATEGORIES:
// 1. Business Rule Violations (Layer A/B):
//    - Empty content, invalid dates, invalid priorities
//    - Domain logic failures
// 2. Database Constraint Violations (Layer C):
//    - Foreign key violations, duplicate records, null constraints
//    - Infrastructure failures mapped from DatabaseError
//
// USAGE EXAMPLE:
// throw ValidationError.emptyAction("No title, measurements, or goals provided")
// catch ValidationError.invalidMeasure(let message) {
//     showAlert(message) // User sees friendly text
// }

import Foundation

/// Validation errors with user-friendly messages
/// Thrown during form validation (Layer A/B) or database operations (Layer C)
public enum ValidationError: LocalizedError {

    // MARK: - Business Rule Violations (Layer A/B)

    /// Action has no meaningful content (no title, measurements, or goal links)
    case emptyAction(String)

    /// Value has insufficient definition
    case emptyValue(String)

    /// Expectation (goal intent) is malformed or incomplete
    case invalidExpectation(String)

    /// Date range is invalid (start > end, or dates in wrong order)
    case invalidDateRange(String)

    /// Priority value out of valid range (1-10)
    case invalidPriority(String)

    /// References between entities are inconsistent (e.g., measurement.actionId != action.id)
    case inconsistentReference(String)

    /// Goal appears to be a duplicate of an existing goal (semantic similarity)
    case duplicateGoal(title: String, similarTo: String, similarity: Double)

    // MARK: - Database Constraint Violations (Layer C)

    /// Measure (unit type) doesn't exist or was deleted
    case invalidMeasure(String)

    /// Goal doesn't exist or was deleted
    case invalidGoal(String)

    /// Attempted to create duplicate record (unique constraint violation)
    case duplicateRecord(String)

    /// Required field is missing (NOT NULL constraint)
    case missingRequiredField(String)

    /// Foreign key constraint failed (referenced record doesn't exist)
    case foreignKeyViolation(String)

    /// Generic database constraint violation
    case databaseConstraint(String)

    // MARK: - User-Facing Messages

    /// User-friendly error message for display in UI
    public var userMessage: String {
        switch self {
        // Business rules
        case .emptyAction(let details):
            return "Action must have a title, description, measurements, or goal links. \(details)"
        case .emptyValue(let details):
            return "Value must have a name and description. \(details)"
        case .invalidExpectation(let details):
            return "Goal must have a clear intent. \(details)"
        case .invalidDateRange(let details):
            return "Date range is invalid. \(details)"
        case .invalidPriority(let details):
            return "Priority must be between 1-10. \(details)"
        case .inconsistentReference(let details):
            return "Internal consistency error. \(details)"
        case .duplicateGoal(let title, let similarTo, let similarity):
            let percent = Int(similarity * 100)
            return "'\(title)' is \(percent)% similar to existing goal '\(similarTo)'. Consider editing the existing goal instead of creating a duplicate."

        // Database constraints
        case .invalidMeasure(let details):
            return "The selected measurement type is no longer available. \(details)"
        case .invalidGoal(let details):
            return "The linked goal is no longer available. \(details)"
        case .duplicateRecord(let details):
            return "This record already exists. \(details)"
        case .missingRequiredField(let details):
            return "Required field is missing: \(details)"
        case .foreignKeyViolation(let details):
            return "Referenced record no longer exists. \(details)"
        case .databaseConstraint(let details):
            return "Database error: \(details)"
        }
    }

    /// Conforms to LocalizedError for SwiftUI integration
    public var errorDescription: String? {
        return userMessage
    }
}

// MARK: - Sendable Conformance

// ValidationError is Sendable because:
// - It's an enum (value type)
// - All associated values are String or primitive types (all Sendable)
// - Safe to pass between actor boundaries
// - No mutable state
extension ValidationError: @unchecked Sendable {}

// MARK: - Future Extensions

// TODO: Add error codes for analytics tracking
// extension ValidationError {
//     var errorCode: String { ... }
// }

// TODO: Add severity levels for error prioritization
// extension ValidationError {
//     enum Severity { case warning, error, critical }
//     var severity: Severity { ... }
// }

// TODO: Add recovery suggestions for actionable errors
// extension ValidationError {
//     var recoverySuggestion: String? { ... }
// }
