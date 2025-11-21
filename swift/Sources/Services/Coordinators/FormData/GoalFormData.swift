//
// GoalFormData.swift
// Written by Claude Code on 2025-11-03
//
// PURPOSE: Input DTO for GoalCoordinator
// STRUCTURE: Combines Expectation + Goal + ExpectationMeasure[] + GoalRelevance[] + TermGoalAssignment?
// USAGE: Assembled by GoalFormViewModel, consumed by GoalCoordinator
//

import Foundation
import Models

/// Form data for goal creation/editing
///
/// Captures all user input needed to create:
/// 1. Expectation (title, description, importance, urgency)
/// 2. Goal (dates, action plan, term length)
/// 3. ExpectationMeasure[] (metric targets)
/// 4. GoalRelevance[] (value alignments)
/// 5. TermGoalAssignment? (optional term assignment)
public struct GoalFormData: ExpectationFormDataBase, Sendable {

    // MARK: - Expectation Fields (ExpectationFormDataBase)

    public var title: String
    public var detailedDescription: String
    public var freeformNotes: String
    public var expectationImportance: Int
    public var expectationUrgency: Int

    // MARK: - Goal Fields

    public let startDate: Date?
    public let targetDate: Date?
    public let actionPlan: String?
    public let expectedTermLength: Int?

    // MARK: - Relationships

    /// Measurement targets for this goal (converted to ExpectationMeasure records)
    /// Example: "Run 120 km" → ExpectationMeasure(measureId: km, targetValue: 120)
    public let measureTargets: [ExpectationMeasureFormData]

    /// Value alignments for this goal (converted to GoalRelevance records)
    public let valueAlignments: [ValueAlignmentInput]

    /// Optional term assignment (converted to TermGoalAssignment record)
    public let termId: UUID?

    // MARK: - Initialization

    public init(
        title: String,
        detailedDescription: String = "",
        freeformNotes: String = "",
        expectationImportance: Int = 8,  // Default for goals
        expectationUrgency: Int = 5,     // Default for goals
        startDate: Date? = nil,
        targetDate: Date? = nil,
        actionPlan: String? = nil,
        expectedTermLength: Int? = nil,
        measureTargets: [ExpectationMeasureFormData] = [],
        valueAlignments: [ValueAlignmentInput] = [],
        termId: UUID? = nil
    ) {
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.expectationImportance = expectationImportance
        self.expectationUrgency = expectationUrgency
        self.startDate = startDate
        self.targetDate = targetDate
        self.actionPlan = actionPlan
        self.expectedTermLength = expectedTermLength
        self.measureTargets = measureTargets
        self.valueAlignments = valueAlignments
        self.termId = termId
    }

    /// Initialize form data from existing GoalData (for editing)
    ///
    /// Maps all fields from GoalData back to editable form structure.
    /// Used when user taps "Edit" on an existing goal.
    ///
    /// **Pattern**: GoalData (display) → GoalFormData (editing) → DataStore.updateGoal()
    ///
    /// **Usage**:
    /// ```swift
    /// struct GoalFormView: View {
    ///     let goalToEdit: GoalData?
    ///     @State private var formData: GoalFormData
    ///
    ///     init(goalToEdit: GoalData? = nil) {
    ///         if let goal = goalToEdit {
    ///             _formData = State(initialValue: GoalFormData(from: goal))
    ///         } else {
    ///             _formData = State(initialValue: GoalFormData())
    ///         }
    ///     }
    /// }
    /// ```
    public init(from goalData: GoalData) {
        // Expectation fields
        self.title = goalData.title ?? ""
        self.detailedDescription = goalData.detailedDescription ?? ""
        self.freeformNotes = goalData.freeformNotes ?? ""
        self.expectationImportance = goalData.expectationImportance
        self.expectationUrgency = goalData.expectationUrgency

        // Goal fields
        self.startDate = goalData.startDate
        self.targetDate = goalData.targetDate
        self.actionPlan = goalData.actionPlan
        self.expectedTermLength = goalData.expectedTermLength

        // Map measure targets (GoalData.MeasureTarget → ExpectationMeasureFormData)
        self.measureTargets = goalData.measureTargets.map { target in
            ExpectationMeasureFormData(
                id: target.id,
                measureId: target.measureId,
                unit: nil,  // Existing measure, no new unit needed
                measureType: nil,
                measureTitle: nil,
                targetValue: target.targetValue,
                notes: target.freeformNotes
            )
        }

        // Map value alignments (GoalData.ValueAlignment → ValueAlignmentInput)
        self.valueAlignments = goalData.valueAlignments.map { alignment in
            ValueAlignmentInput(
                id: alignment.id,
                valueId: alignment.valueId,
                alignmentStrength: alignment.alignmentStrength ?? 5,
                relevanceNotes: alignment.relevanceNotes
            )
        }

        // Map term assignment (optional)
        self.termId = goalData.termAssignment?.termId
    }
}
