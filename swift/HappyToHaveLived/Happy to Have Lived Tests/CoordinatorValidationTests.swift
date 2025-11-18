// CoordinatorValidationTests.swift
// Written by Claude Code on 2025-11-09
//
// PURPOSE:
// Comprehensive validation tests for coordinators using the new ValidationRules layer.
// Tests the two-phase validation pattern:
//   Phase 1: ValidationRules.validateFormData() - business rules before assembly
//   Phase 2: ValidationRules.validateComplete() - referential integrity after assembly
//
// COVERAGE:
// - PersonalValue: title requirement, priority range
// - Action: content requirement, duration range, start time validation
// - Goal: title/description requirement, importance/urgency range, date range, metric/alignment validation
// - Term: date range validation, term number validation
//
// TESTING APPROACH:
// - Direct validation testing (no JSON, no database)
// - Construct FormData in code with known valid/invalid values
// - Assert specific error types for bad data
// - Use Swift Testing framework for clear test structure

import Foundation
import Testing

@testable import Models
@testable import Services

// MARK: - PersonalValue Validation Tests

@Suite("PersonalValue Validation")
struct PersonalValueValidationTests {

    // MARK: - Phase 1: Form Data Validation

    @Test("Accepts value with title")
    func acceptsValueWithTitle() throws {
        let formData = PersonalValueFormData(
            title: "Health and Wellness",
            detailedDescription: nil,
            valueLevel: .major,
            priority: 10
        )

        // Should NOT throw
        try PersonalValueValidation.validateFormData(formData)
    }

    @Test("Rejects value with empty title")
    func rejectsValueWithEmptyTitle() throws {
        let formData = PersonalValueFormData(
            title: "",
            detailedDescription: nil,
            valueLevel: .major,
            priority: 10
        )

        // Should throw ValidationError.emptyValue
        #expect(throws: ValidationError.self) {
            try PersonalValueValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try PersonalValueValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.emptyValue to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Title"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects value with whitespace-only title")
    func rejectsValueWithWhitespaceTitle() throws {
        let formData = PersonalValueFormData(
            title: "   ",
            detailedDescription: nil,
            valueLevel: .major,
            priority: 10
        )

        // Should throw ValidationError.emptyValue
        #expect(throws: ValidationError.self) {
            try PersonalValueValidation.validateFormData(formData)
        }
    }

    @Test("Accepts valid priority values", arguments: [1, 25, 50, 75, 100])
    func acceptsValidPriority(priority: Int) throws {
        let formData = PersonalValueFormData(
            title: "Test Value",
            valueLevel: .major,
            priority: priority
        )

        // Should NOT throw
        try PersonalValueValidation.validateFormData(formData)
    }

    @Test("Rejects priority below 1")
    func rejectsPriorityBelowOne() throws {
        let formData = PersonalValueFormData(
            title: "Test Value",
            valueLevel: .major,
            priority: 0
        )

        // Should throw ValidationError.invalidPriority
        #expect(throws: ValidationError.self) {
            try PersonalValueValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try PersonalValueValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidPriority to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Priority"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects priority above 100")
    func rejectsPriorityAbove100() throws {
        let formData = PersonalValueFormData(
            title: "Test Value",
            valueLevel: .major,
            priority: 150
        )

        // Should throw ValidationError.invalidPriority
        #expect(throws: ValidationError.self) {
            try PersonalValueValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try PersonalValueValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidPriority to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Priority"))
            #expect(message.contains("1-100"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Accepts nil priority (uses default from valueLevel)")
    func acceptsNilPriority() throws {
        let formData = PersonalValueFormData(
            title: "Test Value",
            valueLevel: .major,
            priority: nil
        )

        // Should NOT throw (nil priority is valid, default will be used)
        try PersonalValueValidation.validateFormData(formData)
    }
}

// MARK: - Action Validation Tests

@Suite("Action Validation")
struct ActionValidationTests {

    // MARK: - Phase 1: Form Data Validation

    @Test("Accepts action with title")
    func acceptsActionWithTitle() throws {
        let formData = ActionFormData(
            title: "Morning run",
            durationMinutes: 30,
            startTime: Date()
        )

        // Should NOT throw
        try ActionValidation.validateFormData(formData)
    }

    @Test("Accepts action with measurements only (no title)")
    func acceptsActionWithMeasurements() throws {
        let formData = ActionFormData(
            title: "",
            detailedDescription: "",
            freeformNotes: "",
            durationMinutes: 0,
            startTime: Date(),
            measurements: [
                MeasurementInput(
                    measureId: UUID(),
                    value: 5.2
                )
            ]
        )

        // Should NOT throw (has measurements)
        try ActionValidation.validateFormData(formData)
    }

    @Test("Accepts action with goal links only (no title or measurements)")
    func acceptsActionWithGoalLinks() throws {
        let formData = ActionFormData(
            title: "",
            detailedDescription: "",
            freeformNotes: "",
            durationMinutes: 0,
            startTime: Date(),
            measurements: [],
            goalContributions: [UUID()]
        )

        // Should NOT throw (has goal links)
        try ActionValidation.validateFormData(formData)
    }

    @Test("Rejects action with no content")
    func rejectsActionWithNoContent() throws {
        let formData = ActionFormData(
            title: "",
            detailedDescription: "",
            freeformNotes: "",
            durationMinutes: 0,
            startTime: Date(),
            measurements: [],
            goalContributions: []
        )

        // Should throw ValidationError.emptyAction
        #expect(throws: ValidationError.self) {
            try ActionValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try ActionValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.emptyAction to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Action"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Accepts zero duration")
    func acceptsZeroDuration() throws {
        let formData = ActionFormData(
            title: "Quick task",
            durationMinutes: 0,
            startTime: Date()
        )

        // Should NOT throw (0 is valid for duration)
        try ActionValidation.validateFormData(formData)
    }

    @Test("Accepts positive duration")
    func acceptsPositiveDuration() throws {
        let formData = ActionFormData(
            title: "Running",
            durationMinutes: 45.5,
            startTime: Date()
        )

        // Should NOT throw
        try ActionValidation.validateFormData(formData)
    }

    @Test("Rejects negative duration")
    func rejectsNegativeDuration() throws {
        let formData = ActionFormData(
            title: "Test",
            durationMinutes: -10,
            startTime: Date()
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try ActionValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try ActionValidation.validateFormData(formData)
            Issue.record("Expected ValidationError to be thrown for negative duration")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Duration"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Accepts past start time")
    func acceptsPastStartTime() throws {
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago
        let formData = ActionFormData(
            title: "Past action",
            startTime: pastDate
        )

        // Should NOT throw
        try ActionValidation.validateFormData(formData)
    }

    @Test("Accepts current start time")
    func acceptsCurrentStartTime() throws {
        let formData = ActionFormData(
            title: "Current action",
            startTime: Date()
        )

        // Should NOT throw
        try ActionValidation.validateFormData(formData)
    }

    @Test("Rejects future start time")
    func rejectsFutureStartTime() throws {
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour from now
        let formData = ActionFormData(
            title: "Future action",
            startTime: futureDate
        )

        // Should throw ValidationError.invalidDateRange
        #expect(throws: ValidationError.self) {
            try ActionValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try ActionValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidDateRange to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Start time"))
            #expect(message.contains("future"))
            print("✅ Caught expected error: \(message)")
        }
    }
}

// MARK: - Goal Validation Tests

@Suite("Goal Validation")
struct GoalValidationTests {

    // MARK: - Phase 1: Form Data Validation

    @Test("Accepts goal with title")
    func acceptsGoalWithTitle() throws {
        let formData = GoalFormData(
            title: "Run a marathon",
            expectationImportance: 8,
            expectationUrgency: 5,
            startDate: Date(),
            targetDate: Date().addingTimeInterval(86400 * 70)  // 70 days from now
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Accepts goal with description only")
    func acceptsGoalWithDescriptionOnly() throws {
        let formData = GoalFormData(
            title: "",
            detailedDescription: "Complete a full marathon distance",
            expectationImportance: 8,
            expectationUrgency: 5,
            startDate: Date(),
            targetDate: Date().addingTimeInterval(86400 * 70)
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Rejects goal without title or description")
    func rejectsGoalWithoutTitleOrDescription() throws {
        let formData = GoalFormData(
            title: "",
            detailedDescription: "",
            expectationImportance: 8,
            expectationUrgency: 5
        )

        // Should throw ValidationError.emptyValue
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try GoalValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.emptyValue to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Goal"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Accepts valid importance values", arguments: [1, 3, 5, 8, 10])
    func acceptsValidImportance(importance: Int) throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: importance,
            expectationUrgency: 5
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Rejects importance below 1")
    func rejectsImportanceBelow1() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 0,
            expectationUrgency: 5
        )

        // Should throw ValidationError.invalidPriority
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try GoalValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidPriority to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Importance"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects importance above 10")
    func rejectsImportanceAbove10() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 15,
            expectationUrgency: 5
        )

        // Should throw ValidationError.invalidPriority
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }
    }

    @Test("Accepts valid urgency values", arguments: [1, 3, 5, 8, 10])
    func acceptsValidUrgency(urgency: Int) throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: urgency
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Rejects urgency below 1")
    func rejectsUrgencyBelow1() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 0
        )

        // Should throw ValidationError.invalidPriority
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }
    }

    @Test("Rejects urgency above 10")
    func rejectsUrgencyAbove10() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 12
        )

        // Should throw ValidationError.invalidPriority
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }
    }

    @Test("Accepts start date before target date")
    func acceptsValidDateRange() throws {
        let startDate = Date()
        let targetDate = Date().addingTimeInterval(86400 * 70)  // 70 days later

        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            startDate: startDate,
            targetDate: targetDate
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Accepts equal start and target dates")
    func acceptsEqualDates() throws {
        let date = Date()

        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            startDate: date,
            targetDate: date
        )

        // Should NOT throw (equal dates are valid for goals)
        try GoalValidation.validateFormData(formData)
    }

    @Test("Rejects start date after target date")
    func rejectsInvalidDateRange() throws {
        let startDate = Date()
        let targetDate = Date().addingTimeInterval(-86400)  // 1 day earlier

        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            startDate: startDate,
            targetDate: targetDate
        )

        // Should throw ValidationError.invalidDateRange
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try GoalValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidDateRange to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("date"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Accepts positive metric target values")
    func acceptsPositiveMetricTargets() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            measureTargets: [
                ExpectationMeasureFormData(measureId: UUID(), targetValue: 5.0),
                ExpectationMeasureFormData(measureId: UUID(), targetValue: 100.0),
            ]
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Rejects zero metric target value")
    func rejectsZeroMetricTarget() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            measureTargets: [
                ExpectationMeasureFormData(measureId: UUID(), targetValue: 0.0)
            ]
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try GoalValidation.validateFormData(formData)
            Issue.record("Expected ValidationError to be thrown for zero metric target")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Metric target"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects negative metric target value")
    func rejectsNegativeMetricTarget() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            measureTargets: [
                ExpectationMeasureFormData(measureId: UUID(), targetValue: -5.0)
            ]
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }
    }

    @Test("Accepts valid alignment strengths", arguments: [1, 3, 5, 8, 10])
    func acceptsValidAlignmentStrength(strength: Int) throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            valueAlignments: [
                ValueAlignmentInput(valueId: UUID(), alignmentStrength: strength)
            ]
        )

        // Should NOT throw
        try GoalValidation.validateFormData(formData)
    }

    @Test("Rejects alignment strength below 1")
    func rejectsAlignmentStrengthBelow1() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            valueAlignments: [
                ValueAlignmentInput(valueId: UUID(), alignmentStrength: 0)
            ]
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try GoalValidation.validateFormData(formData)
            Issue.record("Expected ValidationError to be thrown for alignment strength below 1")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Alignment strength"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects alignment strength above 10")
    func rejectsAlignmentStrengthAbove10() throws {
        let formData = GoalFormData(
            title: "Test Goal",
            expectationImportance: 8,
            expectationUrgency: 5,
            valueAlignments: [
                ValueAlignmentInput(valueId: UUID(), alignmentStrength: 15)
            ]
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try GoalValidation.validateFormData(formData)
        }
    }
}

// MARK: - Term Validation Tests

@Suite("Term Validation")
struct TermValidationTests {

    // MARK: - Phase 1: Form Data Validation

    @Test("Accepts term with valid date range")
    func acceptsTermWithValidDateRange() throws {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(86400 * 70)  // 70 days later

        let formData = TimePeriodFormData(
            title: "Term 1",
            startDate: startDate,
            targetDate: endDate,
            specialization: .term(number: 1)
        )

        // Should NOT throw
        try TermValidation.validateFormData(formData)
    }

    @Test("Rejects term with equal start and end dates")
    func rejectsTermWithEqualDates() throws {
        let date = Date()

        let formData = TimePeriodFormData(
            title: "Term 1",
            startDate: date,
            targetDate: date,
            specialization: .term(number: 1)
        )

        // Should throw ValidationError.invalidDateRange
        // (Terms require strictly before, not equal)
        #expect(throws: ValidationError.self) {
            try TermValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try TermValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidDateRange to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("date"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects term with start date after end date")
    func rejectsTermWithInvalidDateRange() throws {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(-86400)  // 1 day earlier

        let formData = TimePeriodFormData(
            title: "Term 1",
            startDate: startDate,
            targetDate: endDate,
            specialization: .term(number: 1)
        )

        // Should throw ValidationError.invalidDateRange
        #expect(throws: ValidationError.self) {
            try TermValidation.validateFormData(formData)
        }
    }

    @Test("Accepts positive term numbers", arguments: [1, 2, 5, 10, 100])
    func acceptsPositiveTermNumber(termNumber: Int) throws {
        let formData = TimePeriodFormData(
            title: "Term \(termNumber)",
            startDate: Date(),
            targetDate: Date().addingTimeInterval(86400 * 70),
            specialization: .term(number: termNumber)
        )

        // Should NOT throw
        try TermValidation.validateFormData(formData)
    }

    @Test("Rejects term number of zero")
    func rejectsTermNumberZero() throws {
        let formData = TimePeriodFormData(
            title: "Term 0",
            startDate: Date(),
            targetDate: Date().addingTimeInterval(86400 * 70),
            specialization: .term(number: 0)
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try TermValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try TermValidation.validateFormData(formData)
            Issue.record("Expected ValidationError to be thrown for term number 0")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("Term number"))
            print("✅ Caught expected error: \(message)")
        }
    }

    @Test("Rejects negative term number")
    func rejectsNegativeTermNumber() throws {
        let formData = TimePeriodFormData(
            title: "Term -1",
            startDate: Date(),
            targetDate: Date().addingTimeInterval(86400 * 70),
            specialization: .term(number: -1)
        )

        // Should throw ValidationError
        #expect(throws: ValidationError.self) {
            try TermValidation.validateFormData(formData)
        }
    }

    @Test("Rejects non-term specialization")
    func rejectsNonTermSpecialization() throws {
        let formData = TimePeriodFormData(
            title: "Year 2025",
            startDate: Date(),
            targetDate: Date().addingTimeInterval(86400 * 365),
            specialization: .year(yearNumber: 2025)
        )

        // Should throw ValidationError.invalidExpectation
        // (TermValidation requires .term specialization)
        #expect(throws: ValidationError.self) {
            try TermValidation.validateFormData(formData)
        }

        // Verify error details
        do {
            try TermValidation.validateFormData(formData)
            Issue.record("Expected ValidationError.invalidExpectation to be thrown")
        } catch let error as ValidationError {
            let message = error.userMessage
            #expect(message.contains("term"))
            print("✅ Caught expected error: \(message)")
        }
    }
}

//
// TOTAL: 42 base tests + parameterized expansions
//
// WHAT EACH TEST VALIDATES:
//
// PersonalValue:
// - Title requirement (non-empty, non-whitespace)
// - Priority range (1-100, nil OK)
//
// Action:
// - Content requirement (title OR measurements OR goal links)
// - Duration range (>= 0)
// - Start time validation (not in future)
//
// Goal:
// - Title/description requirement (at least one)
// - Importance range (1-10)
// - Urgency range (1-10)
// - Date range validation (start <= target)
// - Metric target values (> 0)
// - Alignment strengths (1-10)
//
// Term:
// - Date range validation (start < target, strictly before)
// - Term number validation (> 0)
// - Specialization type validation (must be .term)
//
// ERROR ASSERTION STRATEGY:
// 1. Use #expect(throws: ValidationError.self) for type checking
// 2. Use do-catch to verify error message content
// 3. Print error messages for debugging visibility
// 4. Check that error messages contain relevant field names
//
// NOTES:
// - No database required (pure validation testing)
// - No JSON loading required (construct FormData in code)
// - Phase 2 validation (validateComplete) requires assembled entities
//   → Not tested here (requires coordinator integration or mock entities)
// - All tests use Swift Testing framework (@Test, @Suite, #expect)
