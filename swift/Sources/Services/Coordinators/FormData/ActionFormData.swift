//
// ActionFormData.swift
// Form state for Action creation/editing
//
// Written by Claude Code on 2025-11-01
// Updated by Claude Code on 2025-11-02 (moved to FormData/, made Sendable)
// Updated by Claude Code on 2025-11-17 for get-or-create pattern
//
// PURPOSE:
// Input DTO for ActionCoordinator. Holds form state and validates before persistence.
// Follows ValueFormData and TimePeriodFormData patterns.
//
// GET-OR-CREATE PATTERN:
// - User can select existing measure (measureId) OR
// - User can create new measure inline (unit + measureType + optional title)
// - ActionCoordinator calls MeasureCoordinator.getOrCreate() for new measures

import Foundation
import Models

/// Form state for action input
///
/// Holds user input and validates it before coordinator persistence.
/// Sendable for safe passage across actor boundaries (ViewModel → Coordinator).
///
/// **Usage**:
/// ```swift
/// let formData = ActionFormData(
///     title: "Morning run",
///     durationMinutes: 28.0,
///     startTime: Date(),
///     measurements: [
///         MeasurementInput(measureId: kilometersId, value: 5.2),
///         MeasurementInput(measureId: minutesId, value: 28.0)
///     ],
///     goalContributions: [runningGoalId, healthGoalId]
/// )
///
/// let action = try await coordinator.create(from: formData)
/// ```
public struct ActionFormData: Sendable {

    // MARK: - Properties

    /// Required: The name of the action
    /// Example: "Morning run", "Team meeting", "Guitar practice"
    public let title: String

    /// Optional: Detailed description of what was done
    /// Example: "5K route through the park, felt strong"
    public let detailedDescription: String

    /// Optional: Free-form notes
    /// Example: "Weather was perfect, saw three deer"
    public let freeformNotes: String

    /// Optional: How long the action took (in minutes)
    /// Example: 28.0 for 28 minutes
    /// Zero means no duration tracked
    public let durationMinutes: Double

    /// When this action occurred
    /// Defaults to now, but can be changed for retroactive logging
    public let startTime: Date

    /// Measurements associated with this action
    /// Example: [MeasurementInput(measureId: km.id, value: 5.2)]
    public let measurements: [MeasurementInput]

    /// Goal IDs this action contributes toward
    /// Example: [runningGoalId, healthGoalId]
    /// ActionCoordinator creates ActionGoalContribution records for each
    public let goalContributions: Set<UUID>

    // MARK: - Initialization

    public init(
        title: String = "",
        detailedDescription: String = "",
        freeformNotes: String = "",
        durationMinutes: Double = 0,
        startTime: Date = Date(),
        measurements: [MeasurementInput] = [],
        goalContributions: Set<UUID> = []
    ) {
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.durationMinutes = durationMinutes
        self.startTime = startTime
        self.measurements = measurements
        self.goalContributions = goalContributions
    }
}

// MARK: - MeasurementInput Helper

/// Input struct for action measurements with get-or-create support
///
/// **Usage Pattern 1** (Select existing measure):
/// ```swift
/// MeasurementInput(
///     measureId: existingMeasure.id,
///     value: 5.2
/// )
/// ```
///
/// **Usage Pattern 2** (Create new measure inline):
/// ```swift
/// MeasurementInput(
///     unit: "km",
///     measureType: "distance",
///     measureTitle: "Distance in kilometers",  // Optional
///     value: 5.2
/// )
/// ```
///
/// **Validation**: Requires EITHER `measureId` OR (`unit` + `measureType`)
///
/// **Coordinator Integration**:
/// - ActionCoordinator checks which pattern is used
/// - If measureId: Uses existing measure
/// - If unit+measureType: Calls `MeasureCoordinator.getOrCreate()`
/// - Result: Measure guaranteed to exist before MeasuredAction insert
public struct MeasurementInput: Identifiable, Sendable {
    public let id: UUID

    // PATTERN 1: Reference existing measure
    public var measureId: UUID?

    // PATTERN 2: Create new measure inline
    public var unit: String?
    public var measureType: String?
    public var measureTitle: String?  // Optional custom title

    // Common fields
    public var value: Double

    /// Validation: Requires EITHER measureId OR (unit + measureType), AND value > 0
    public var isValid: Bool {
        let hasMeasure = measureId != nil
        let hasNewMeasure = unit != nil && measureType != nil &&
                           !unit!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           !measureType!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasMeasure || hasNewMeasure) && value > 0
    }

    public init(
        id: UUID = UUID(),
        measureId: UUID? = nil,
        unit: String? = nil,
        measureType: String? = nil,
        measureTitle: String? = nil,
        value: Double = 0.0
    ) {
        self.id = id
        self.measureId = measureId
        self.unit = unit
        self.measureType = measureType
        self.measureTitle = measureTitle
        self.value = value
    }
}
