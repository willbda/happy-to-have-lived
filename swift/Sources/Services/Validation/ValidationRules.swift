// ValidationRules.swift
// Written by Claude Code on 2025-11-09
//
// PURPOSE:
// Entity-specific validation rules organized by domain entity.
// Each enum provides static validation methods for business rules and referential integrity.
//
// ARCHITECTURE:
// Coordinators call these rules before/after entity assembly:
// - Phase 1: validateFormData() - Business rules on user input
// - Phase 2: validateComplete() - Referential integrity on assembled entities
//
// PATTERN:
// All validation logic delegates to ValidationUtilities for consistent error messages.
// These rules just specify WHICH validations to run for WHICH entity.

import Foundation
import Models

// MARK: - PersonalValue Validation

public enum PersonalValueValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: PersonalValueFormData) throws {
        try ValidationUtilities.requireFieldHasValue(formData.title, field: "Title")
        try ValidationUtilities.requireFieldInRange(formData.priority, 1...100, field: "Priority")
    }

    /// Phase 2: Validate assembled entity
    public static func validateComplete(_ value: PersonalValue) throws {
        guard let priority = value.priority else {
            throw ValidationError.invalidPriority("Priority must be set and in range 1-100")
        }
        try ValidationUtilities.requireFieldInRange(priority, 1...100, field: "Priority")
    }
}

// MARK: - Action Validation

public enum ActionValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: ActionFormData) throws {
        // Rule: Action must have SOME content (text OR measurements OR goal links)
        //
        // NOTE: Uses try? to convert ValidationUtilities check to boolean for OR logic.
        // We can't throw immediately on missing text because actions can be valid with
        // only measurements or goal links. The comprehensive error below explains all options.
        let hasTextContent = (try? ValidationUtilities.requireAnyFieldHasValue(
            [
                (formData.title, "title"),
                (formData.detailedDescription, "description"),
                (formData.freeformNotes, "notes"),
            ],
            entity: "Action"
        )) != nil

        let hasMeasurements = !formData.measurements.isEmpty
        let hasGoalLinks = !formData.goalContributions.isEmpty

        guard hasTextContent || hasMeasurements || hasGoalLinks else {
            throw ValidationError.emptyAction(
                "Action must have title, description, notes, measurements, or goal links"
            )
        }

        // Rule: Duration must be non-negative
        try ValidationUtilities.requireFieldInRange(formData.durationMinutes, 0..., field: "Duration")

        // Rule: Start time cannot be in future
        try ValidationUtilities.requireDateNotInFuture(formData.startTime, field: "Start time")
    }

    /// Phase 2: Validate assembled entity graph
    public static func validateComplete(
        _ action: Action,
        _ measurements: [MeasuredAction],
        _ contributions: [ActionGoalContribution]
    ) throws {
        // Check: All measurements reference this action
        try ValidationUtilities.requireFieldsMatch(
            measurements,
            expectedValue: action.id,
            keyPath: \.actionId,
            items: "Measurements",
            field: "actionId"
        )

        // Check: All contributions reference this action
        try ValidationUtilities.requireFieldsMatch(
            contributions,
            expectedValue: action.id,
            keyPath: \.actionId,
            items: "Contributions",
            field: "actionId"
        )

        // Check: No duplicate measurements
        try ValidationUtilities.requireFieldsUnique(
            measurements,
            keyPath: \.measureId,
            items: "Measurements",
            field: "measureId"
        )
    }
}

// MARK: - Goal Validation

public enum GoalValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: GoalFormData) throws {
        // Rule: Must have title or description
        try ValidationUtilities.requireAnyFieldHasValue(
            [(formData.title, "title"), (formData.detailedDescription, "description")],
            entity: "Goal"
        )

        // Rule: Importance must be 1-10
        try ValidationUtilities.requireFieldInRange(
            formData.expectationImportance,
            1...10,
            field: "Importance"
        )

        // Rule: Urgency must be 1-10
        try ValidationUtilities.requireFieldInRange(
            formData.expectationUrgency,
            1...10,
            field: "Urgency"
        )

        // Rule: Start date must be before target date
        try ValidationUtilities.requireValidDateRange(
            formData.startDate,
            formData.targetDate,
            start: "Start date",
            end: "Target date"
        )

        // Rule: All metric targets must be positive
        try ValidationUtilities.requireFieldInRange(
            formData.measureTargets,
            1...,
            keyPath: \.targetValue,
            field: "Metric target values"
        )

        // Rule: All alignment strengths must be 1-10
        try ValidationUtilities.requireFieldInRange(
            formData.valueAlignments,
            1...10,
            keyPath: \.alignmentStrength,
            field: "Alignment strengths"
        )
    }

    /// Phase 2: Validate assembled entity graph
    public static func validateComplete(
        _ expectation: Expectation,
        _ goal: Goal,
        _ measurements: [ExpectationMeasure],
        _ relevances: [GoalRelevance]
    ) throws {
        // Check: Goal references correct expectation
        try ValidationUtilities.requireFieldsMatch(
            goal.expectationId,
            expectation.id,
            field1: "Goal.expectationId",
            field2: "Expectation.id"
        )

        // Check: All measurements reference correct expectation
        try ValidationUtilities.requireFieldsMatch(
            measurements,
            expectedValue: expectation.id,
            keyPath: \.expectationId,
            items: "Measurements",
            field: "expectationId"
        )

        // Check: All relevances reference correct goal
        try ValidationUtilities.requireFieldsMatch(
            relevances,
            expectedValue: goal.id,
            keyPath: \.goalId,
            items: "Relevances",
            field: "goalId"
        )

        // Check: No duplicate measurements
        try ValidationUtilities.requireFieldsUnique(
            measurements,
            keyPath: \.measureId,
            items: "Measurements",
            field: "measureId"
        )

        // Check: No duplicate relevances
        try ValidationUtilities.requireFieldsUnique(
            relevances,
            keyPath: \.valueId,
            items: "Relevances",
            field: "valueId"
        )
    }
}

// MARK: - Term Validation

public enum TermValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: TimePeriodFormData) throws {
        // Rule: Start date must be before target date (strictly before for terms)
        try ValidationUtilities.requireValidDateRange(
            formData.startDate,
            formData.targetDate,
            start: "Start date",
            end: "Target date",
            allowEqual: false
        )

        // Rule: Must be a term specialization with valid term number
        guard case .term(let termNumber) = formData.specialization else {
            throw ValidationError.invalidExpectation(
                "TimePeriodFormData must have .term specialization for TermValidation"
            )
        }

        // Rule: Term number must be positive
        try ValidationUtilities.requireFieldInRange(termNumber, 1..., field: "Term number")
    }

    /// Phase 2: Validate assembled entity graph
    public static func validateComplete(
        _ timePeriod: TimePeriod,
        _ goalTerm: GoalTerm,
        _ assignments: [TermGoalAssignment]
    ) throws {
        // Check: GoalTerm references correct timePeriod
        try ValidationUtilities.requireFieldsMatch(
            goalTerm.timePeriodId,
            timePeriod.id,
            field1: "GoalTerm.timePeriodId",
            field2: "TimePeriod.id"
        )

        // Check: All assignments reference correct term
        try ValidationUtilities.requireFieldsMatch(
            assignments,
            expectedValue: goalTerm.id,
            keyPath: \.termId,
            items: "Assignments",
            field: "termId"
        )

        // Check: No duplicate goal assignments
        try ValidationUtilities.requireFieldsUnique(
            assignments,
            keyPath: \.goalId,
            items: "Assignments",
            field: "goalId"
        )
    }
}

// MARK: - Milestone Validation

public enum MilestoneValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: MilestoneFormData) throws {
        // Validate shared expectation fields (title, importance, urgency)
        try formData.validateExpectationFields()

        // No additional milestone-specific validation needed
        // (targetDate is just a Date, no range constraints)
    }

    /// Phase 2: Validate assembled entity graph
    public static func validateComplete(
        _ expectation: Expectation,
        _ milestone: Milestone
    ) throws {
        // Check: Milestone references correct expectation
        try ValidationUtilities.requireFieldsMatch(
            milestone.expectationId,
            expectation.id,
            field1: "Milestone.expectationId",
            field2: "Expectation.id"
        )

        // Check: Expectation type is milestone
        guard expectation.expectationType == .milestone else {
            throw ValidationError.invalidExpectation(
                "Expectation type must be 'milestone', got '\(expectation.expectationType)'"
            )
        }
    }
}

// MARK: - Obligation Validation

public enum ObligationValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: ObligationFormData) throws {
        // Validate shared expectation fields (title, importance, urgency)
        try formData.validateExpectationFields()

        // No additional obligation-specific validation needed
        // (deadline is just a Date, requestedBy and consequence are optional text)
    }

    /// Phase 2: Validate assembled entity graph
    public static func validateComplete(
        _ expectation: Expectation,
        _ obligation: Obligation
    ) throws {
        // Check: Obligation references correct expectation
        try ValidationUtilities.requireFieldsMatch(
            obligation.expectationId,
            expectation.id,
            field1: "Obligation.expectationId",
            field2: "Expectation.id"
        )

        // Check: Expectation type is obligation
        guard expectation.expectationType == .obligation else {
            throw ValidationError.invalidExpectation(
                "Expectation type must be 'obligation', got '\(expectation.expectationType)'"
            )
        }
    }
}

// MARK: - Measure Validation

public enum MeasureValidation {

    /// Phase 1: Validate business rules on form data
    public static func validateFormData(_ formData: MeasureFormData) throws {
        // Rule: Title required
        try ValidationUtilities.requireFieldHasValue(formData.title, field: "Measure title")

        // Rule: Unit required
        try ValidationUtilities.requireFieldHasValue(formData.unit, field: "Measure unit")

        // Rule: MeasureType required
        try ValidationUtilities.requireFieldHasValue(formData.measureType, field: "Measure type")

        // Rule: Conversion logic consistency
        if let canonicalUnit = formData.canonicalUnit,
            !canonicalUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            guard let conversionFactor = formData.conversionFactor, conversionFactor > 0 else {
                throw ValidationError.databaseConstraint(
                    "Conversion factor must be > 0 when canonical unit is specified"
                )
            }
        }
    }

    /// Phase 2: Validate assembled entity
    public static func validateComplete(_ measure: Measure) throws {
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

// MARK: - Design Notes

// ARCHITECTURE DECISIONS:
//
// 1. WHY STATIC METHODS?
//    - No instance state needed
//    - Matches ValidationUtilities pattern
//    - Simpler call site: ActionValidation.validateFormData(data)
//    - No protocol boilerplate
//
// 2. WHY SEPARATE ENUMS PER ENTITY?
//    - Clear organization (all PersonalValue rules in one place)
//    - Easy to find validation logic
//    - Good documentation structure
//    - Namespace collision prevention
//
// 3. WHY TWO PHASES?
//    - Phase 1: Catch bad user input early (before assembly)
//    - Phase 2: Catch assembly bugs (wrong IDs, duplicate relationships)
//    - Clear separation of concerns
//
// 4. WHY DELEGATE TO ValidationUtilities?
//    - Consistent error messages across all entities
//    - Single source of truth for validation primitives
//    - These rules just specify WHICH checks to run
//    - Avoids duplication of validation logic

// USAGE IN COORDINATORS:
//
// public func create(from formData: PersonalValueFormData) async throws -> PersonalValue {
//     // Phase 1: Validate business rules
//     try PersonalValueValidation.validateFormData(formData)
//
//     // Assemble entity
//     let value = PersonalValue(...)
//
//     // Phase 2: Validate referential integrity
//     try PersonalValueValidation.validateComplete(value)
//
//     // Persist
//     try await repository.save(value)
//     return value
// }

// TESTING PATTERN:
//
// func testRejectsEmptyTitle() throws {
//     let formData = PersonalValueFormData(title: "", ...)
//     XCTAssertThrowsError(try PersonalValueValidation.validateFormData(formData))
// }
//
// No mocking required - just pure functions!
