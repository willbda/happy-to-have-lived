//
// GoalFormModel.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Consolidated form state for goal creation/editing using @Observable
// REPLACES: 17 @State variables in GoalFormView
// ELIMINATES: Manual synchronization with onChange handlers
//
// PATTERN: @Observable with computed properties for single source of truth
//

import Foundation
import Models
import Observation
import Services

/// Consolidated form model for goal creation/editing
///
/// **Pattern**: @Observable with computed properties
/// **Benefits**:
/// - Single source of truth (no duplicate state like selectedValueIds)
/// - Automatic change tracking (no manual @Published needed)
/// - Type-safe computed properties
/// - No onChange synchronization needed
///
/// **Usage**:
/// ```swift
/// @State private var model = GoalFormModel()
/// // or
/// @State private var model = GoalFormModel(from: existingGoal)
/// ```
@Observable
@MainActor
public final class GoalFormModel {

    // MARK: - Basic Info (Expectation fields)

    public var title: String = ""
    public var detailedDescription: String = ""
    public var freeformNotes: String = ""

    // MARK: - Priority

    public var importance: Int
    public var urgency: Int

    // MARK: - Timeline (Goal fields)

    public var startDate: Date = Date()
    public var targetDate: Date
    public var actionPlan: String = ""
    public var expectedTermLength: Int = 10

    // MARK: - Relationships

    public var measureTargets: [ExpectationMeasureFormData] = []
    public var valueAlignments: [ValueAlignmentInput] = []
    public var selectedTermId: UUID?

    // MARK: - Computed Properties (No Manual Sync!)

    /// Selected value IDs derived from alignments
    /// ✅ ELIMINATES: selectedValueIds @State variable
    /// ✅ ELIMINATES: onChange(of: selectedValueIds) sync logic (lines 198-214 in old code)
    public var selectedValueIds: Set<UUID> {
        Set(valueAlignments.compactMap(\.valueId))
    }

    /// Form is valid and ready to submit
    public var canSubmit: Bool {
        !title.isEmpty
    }

    // MARK: - Initialization

    /// Create mode - use defaults
    public init(
        importance: Int = Expectation.defaultImportance(for: .goal),
        urgency: Int = Expectation.defaultUrgency(for: .goal),
        targetDate: Date? = nil
    ) {
        self.importance = importance
        self.urgency = urgency
        self.targetDate = targetDate ?? Calendar.current.date(
            byAdding: .weekOfYear,
            value: 10,
            to: Date()
        ) ?? Date()
    }

    /// Edit mode - initialize from existing goal
    public init(from goalData: GoalData) {
        // Expectation fields
        self.title = goalData.title ?? ""
        self.detailedDescription = goalData.detailedDescription ?? ""
        self.freeformNotes = goalData.freeformNotes ?? ""
        self.importance = goalData.expectationImportance
        self.urgency = goalData.expectationUrgency

        // Goal fields
        self.startDate = goalData.startDate ?? Date()
        self.targetDate = goalData.targetDate ?? Calendar.current.date(
            byAdding: .weekOfYear,
            value: 10,
            to: Date()
        ) ?? Date()
        self.actionPlan = goalData.actionPlan ?? ""
        self.expectedTermLength = goalData.expectedTermLength ?? 10

        // Relationships - convert from GoalData format to form input format
        self.measureTargets = goalData.measureTargets.map { target in
            ExpectationMeasureFormData(
                id: target.id,
                measureId: target.measureId,
                targetValue: target.targetValue,
                notes: target.freeformNotes
            )
        }

        self.valueAlignments = goalData.valueAlignments.map { alignment in
            ValueAlignmentInput(
                id: alignment.id,
                valueId: alignment.valueId,
                alignmentStrength: alignment.alignmentStrength ?? 5,
                relevanceNotes: alignment.relevanceNotes
            )
        }

        self.selectedTermId = goalData.termAssignment?.termId
    }

    // MARK: - Actions

    /// Toggle value selection
    /// ✅ REPLACES: Manual selectedValueIds management + onChange handler
    public func toggleValue(_ valueId: UUID, strength: Int = 5) {
        if let index = valueAlignments.firstIndex(where: { $0.valueId == valueId }) {
            // Already selected - remove it
            valueAlignments.remove(at: index)
        } else {
            // Not selected - add it
            valueAlignments.append(ValueAlignmentInput(
                valueId: valueId,
                alignmentStrength: strength
            ))
        }
        // selectedValueIds updates automatically via computed property!
    }

    /// Add a new measure target
    public func addMeasureTarget() {
        measureTargets.append(ExpectationMeasureFormData())
    }

    /// Remove a measure target
    public func removeMeasureTarget(_ target: ExpectationMeasureFormData) {
        measureTargets.removeAll { $0.id == target.id }
    }

    /// Remove a measure target by ID
    public func removeMeasureTarget(id: UUID) {
        measureTargets.removeAll { $0.id == id }
    }
}
