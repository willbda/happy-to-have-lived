//
// FormDataTransformer.swift
// Written by Claude Code on 2025-11-17
//
// PURPOSE:
// Transform canonical Data types → FormData for coordinator creation.
//
// PATTERN:
// - Data types (ActionData, GoalData) come from CSV/JSON parsing
// - FormData types (ActionFormData, GoalFormData) are input DTOs for coordinators
// - This transformer bridges the gap: parsed data → validated form → creation
//

import Foundation
import Models

/// Transforms canonical Data types to FormData for coordinator input
///
/// **Usage**:
/// ```swift
/// let transformer = FormDataTransformer()
/// let formData = transformer.transformAction(actionData)
/// let action = try await coordinator.create(from: formData)
/// ```
public struct FormDataTransformer {

    public init() {}

    // MARK: - Action Transformation

    /// Transform ActionData → ActionFormData
    ///
    /// **Pattern**:
    /// - Direct field mapping for core action fields
    /// - measurements[] → MeasurementInput[]
    /// - contributions[] → goalContributions Set<UUID>
    public func transformAction(_ data: ActionData) -> ActionFormData {
        // Transform measurements
        let measurements = data.measurements.map { m in
            MeasurementInput(
                id: m.id,
                measureId: m.measureId,
                value: m.value
            )
        }

        // Transform contributions (Data has full Contribution, FormData just needs UUIDs)
        let goalContributions = Set(data.contributions.map { $0.goalId })

        return ActionFormData(
            title: data.title ?? "",
            detailedDescription: data.detailedDescription ?? "",
            freeformNotes: data.freeformNotes ?? "",
            durationMinutes: data.durationMinutes ?? 0,
            startTime: data.startTime ?? data.logTime,  // Use logTime as fallback
            measurements: measurements,
            goalContributions: goalContributions
        )
    }

    // MARK: - Goal Transformation

    /// Transform GoalData → GoalFormData
    ///
    /// **Pattern**:
    /// - Expectation fields mapped directly
    /// - Goal fields mapped directly
    /// - measureTargets[] → MetricTargetInput[]
    /// - valueAlignments[] → ValueAlignmentInput[]
    /// - termAssignment → termId (optional)
    public func transformGoal(_ data: GoalData) -> GoalFormData {
        // Transform measure targets
        let metricTargets = data.measureTargets.map { mt in
            MetricTargetInput(
                id: mt.id,
                measureId: mt.measureId,
                targetValue: mt.targetValue,
                notes: mt.freeformNotes
            )
        }

        // Transform value alignments
        let valueAlignments = data.valueAlignments.map { va in
            ValueAlignmentInput(
                id: va.id,
                valueId: va.valueId,
                alignmentStrength: va.alignmentStrength ?? 5,  // Default to 5 if nil
                relevanceNotes: va.relevanceNotes
            )
        }

        return GoalFormData(
            title: data.title ?? "",
            detailedDescription: data.detailedDescription ?? "",
            freeformNotes: data.freeformNotes ?? "",
            expectationImportance: data.expectationImportance,
            expectationUrgency: data.expectationUrgency,
            startDate: data.startDate,
            targetDate: data.targetDate,
            actionPlan: data.actionPlan,
            expectedTermLength: data.expectedTermLength,
            metricTargets: metricTargets,
            valueAlignments: valueAlignments,
            termId: data.termAssignment?.termId
        )
    }

    // MARK: - PersonalValue Transformation

    /// Transform PersonalValueData → PersonalValueFormData
    ///
    /// **Pattern**: Simplest transformation (flat structure, no nested relationships)
    public func transformPersonalValue(_ data: PersonalValueData) -> PersonalValueFormData {
        // Parse valueLevel string → enum
        let valueLevel = ValueLevel(rawValue: data.valueLevel) ?? .general

        return PersonalValueFormData(
            title: data.title,
            detailedDescription: data.detailedDescription,
            freeformNotes: data.freeformNotes,
            valueLevel: valueLevel,
            priority: data.priority,
            lifeDomain: data.lifeDomain,
            alignmentGuidance: data.alignmentGuidance
        )
    }

    // MARK: - TimePeriod Transformation

    /// Transform TimePeriodData → TimePeriodFormData
    ///
    /// **Pattern**:
    /// - TimePeriod fields (dates, title, description)
    /// - GoalTerm specialization with term number
    /// - GoalTerm fields (theme, reflection, status)
    ///
    /// **Note**: assignedGoalIds not included in FormData (handled separately by coordinator)
    public func transformTimePeriod(_ data: TimePeriodData) -> TimePeriodFormData {
        // Parse status string → enum (if valid)
        let termStatus: TermStatus? = if let statusString = data.status {
            TermStatus(rawValue: statusString)
        } else {
            nil
        }

        // Create term specialization with term number
        let specialization = TimePeriodSpecialization.term(number: data.termNumber)

        return TimePeriodFormData(
            title: data.timePeriodTitle,
            detailedDescription: nil,  // Not included in CSV export
            freeformNotes: nil,        // Not included in CSV export
            startDate: data.startDate,
            targetDate: data.endDate,
            specialization: specialization,
            theme: data.theme,
            reflection: data.reflection,
            status: termStatus
        )
    }
}
