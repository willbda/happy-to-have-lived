//
// ExpectationMeasureFormData.swift
// Written by Claude Code on 2025-11-03
// Renamed from ExpectationMeasureFormData.swift on 2025-11-17
// Updated by Claude Code on 2025-11-17 for get-or-create pattern
//
// PURPOSE: Form data for ExpectationMeasure creation (goal metric targets)
// USAGE: GoalFormData.measureTargets: [ExpectationMeasureFormData]
// VALIDATION: isValid checks EITHER measureId exists OR new measure data provided
//
// ONTOLOGICAL DISTINCTION:
// - ExpectationMeasureFormData = Goal targets ("Run 120 km by June 1")
// - MeasureFormData = Catalog units ("Kilometers" as a measurement unit)
//
// GET-OR-CREATE PATTERN:
// - User can select existing measure (measureId) OR
// - User can create new measure inline (unit + measureType + optional title)
// - GoalCoordinator calls MeasureCoordinator.getOrCreate() for new measures
//

import Foundation

/// Form data for ExpectationMeasure creation with get-or-create support
///
/// **Domain Concept**: Represents a quantifiable target for a goal/expectation.
/// Example: "Run 120 km" creates ExpectationMeasure(measureId: km, targetValue: 120)
///
/// **Usage Pattern 1** (Select existing measure):
/// ```swift
/// ExpectationMeasureFormData(
///     measureId: existingMeasure.id,
///     targetValue: 120.0
/// )
/// ```
///
/// **Usage Pattern 2** (Create new measure inline):
/// ```swift
/// ExpectationMeasureFormData(
///     unit: "km",
///     measureType: "distance",
///     measureTitle: "Distance in kilometers",  // Optional
///     targetValue: 120.0
/// )
/// ```
///
/// **Validation**: Requires EITHER `measureId` OR (`unit` + `measureType`)
///
/// **Coordinator Integration**:
/// - GoalCoordinator checks which pattern is used
/// - If measureId: Uses existing measure
/// - If unit+measureType: Calls `MeasureCoordinator.getOrCreate()`
/// - Result: Measure guaranteed to exist before ExpectationMeasure insert
public struct ExpectationMeasureFormData: Identifiable, Sendable {
    public let id: UUID

    // PATTERN 1: Reference existing measure
    public var measureId: UUID?

    // PATTERN 2: Create new measure inline
    public var unit: String?
    public var measureType: String?
    public var measureTitle: String?  // Optional custom title

    // Common fields
    public var targetValue: Double
    public var notes: String?

    /// Validation: Requires EITHER measureId OR (unit + measureType), AND targetValue > 0
    public var isValid: Bool {
        let hasMeasure = measureId != nil
        let hasNewMeasure = unit != nil && measureType != nil &&
                           !unit!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           !measureType!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasMeasure || hasNewMeasure) && targetValue > 0
    }

    public init(
        id: UUID = UUID(),
        measureId: UUID? = nil,
        unit: String? = nil,
        measureType: String? = nil,
        measureTitle: String? = nil,
        targetValue: Double = 0.0,
        notes: String? = nil
    ) {
        self.id = id
        self.measureId = measureId
        self.unit = unit
        self.measureType = measureType
        self.measureTitle = measureTitle
        self.targetValue = targetValue
        self.notes = notes
    }
}
