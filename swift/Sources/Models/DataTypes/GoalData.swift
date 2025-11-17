//
// GoalData.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Canonical goal data structure that serves both display and export needs.
// Eliminates duplication between GoalWithDetails (display) and GoalExport (export).
//
// DESIGN:
// - ONE struct for all use cases (not 3+ separate types)
// - Flat structure with Goal + Expectation fields at top level
// - Denormalized sub-structs for relationships (not full entities)
// - Codable for direct JSON/CSV export
//

import Foundation

/// Canonical goal data structure - serves both display and export needs
///
/// **Design Philosophy**:
/// - ONE struct to rule them all (not 3+ separate types)
/// - Codable for JSON/CSV export
/// - Sendable for Swift 6 concurrency
/// - Identifiable + Hashable for SwiftUI
/// - Flat structure with denormalized sub-structs
///
/// **Usage**:
/// ```swift
/// // Repository returns this
/// let goals = try await repository.fetchAll()
///
/// // Export uses directly
/// let json = try JSONEncoder().encode(goals)
///
/// // Views use directly (no transformation needed)
/// List(goals) { goal in
///     GoalRow(goal: goal)
/// }
/// ```
public struct GoalData: Identifiable, Hashable, Sendable, Codable {
    // MARK: - Core Identity

    public let id: UUID  // Goal ID (primary key)

    // MARK: - Goal Fields (from goals table)

    public let startDate: Date?
    public let targetDate: Date?
    public let actionPlan: String?
    public let expectedTermLength: Int?

    // MARK: - Expectation Fields (denormalized from expectations table)

    public let expectationId: UUID
    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let expectationImportance: Int
    public let expectationUrgency: Int
    public let logTime: Date

    // MARK: - Denormalized Measurements

    /// Flat measurement target data (no nested ExpectationMeasure entities)
    public struct MeasureTarget: Identifiable, Hashable, Sendable, Codable {
        public let id: UUID  // expectationMeasure.id
        public let measureId: UUID
        public let measureTitle: String?
        public let measureUnit: String
        public let measureType: String
        public let targetValue: Double
        public let freeformNotes: String?
        public let createdAt: Date

        public init(
            id: UUID,
            measureId: UUID,
            measureTitle: String?,
            measureUnit: String,
            measureType: String,
            targetValue: Double,
            freeformNotes: String?,
            createdAt: Date
        ) {
            self.id = id
            self.measureId = measureId
            self.measureTitle = measureTitle
            self.measureUnit = measureUnit
            self.measureType = measureType
            self.targetValue = targetValue
            self.freeformNotes = freeformNotes
            self.createdAt = createdAt
        }
    }

    public let measureTargets: [MeasureTarget]

    // MARK: - Denormalized Value Alignments

    /// Flat value alignment data (no nested PersonalValue entities)
    public struct ValueAlignment: Identifiable, Hashable, Sendable, Codable {
        public let id: UUID  // goalRelevance.id
        public let valueId: UUID
        public let valueTitle: String  // For display convenience
        public let alignmentStrength: Int?
        public let relevanceNotes: String?
        public let createdAt: Date

        public init(
            id: UUID,
            valueId: UUID,
            valueTitle: String,
            alignmentStrength: Int?,
            relevanceNotes: String?,
            createdAt: Date
        ) {
            self.id = id
            self.valueId = valueId
            self.valueTitle = valueTitle
            self.alignmentStrength = alignmentStrength
            self.relevanceNotes = relevanceNotes
            self.createdAt = createdAt
        }
    }

    public let valueAlignments: [ValueAlignment]

    // MARK: - Term Assignment

    /// Flat term assignment data
    public struct TermAssignment: Identifiable, Hashable, Sendable, Codable {
        public let id: UUID  // termGoalAssignment.id
        public let termId: UUID
        public let assignmentOrder: Int?
        public let createdAt: Date

        public init(
            id: UUID,
            termId: UUID,
            assignmentOrder: Int?,
            createdAt: Date
        ) {
            self.id = id
            self.termId = termId
            self.assignmentOrder = assignmentOrder
            self.createdAt = createdAt
        }
    }

    public let termAssignment: TermAssignment?

    // MARK: - Initialization

    public init(
        id: UUID,
        startDate: Date?,
        targetDate: Date?,
        actionPlan: String?,
        expectedTermLength: Int?,
        expectationId: UUID,
        title: String?,
        detailedDescription: String?,
        freeformNotes: String?,
        expectationImportance: Int,
        expectationUrgency: Int,
        logTime: Date,
        measureTargets: [MeasureTarget],
        valueAlignments: [ValueAlignment],
        termAssignment: TermAssignment?
    ) {
        self.id = id
        self.startDate = startDate
        self.targetDate = targetDate
        self.actionPlan = actionPlan
        self.expectedTermLength = expectedTermLength
        self.expectationId = expectationId
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.expectationImportance = expectationImportance
        self.expectationUrgency = expectationUrgency
        self.logTime = logTime
        self.measureTargets = measureTargets
        self.valueAlignments = valueAlignments
        self.termAssignment = termAssignment
    }
}

// MARK: - Convenience Transformations

extension GoalData {
    /// Convenience accessor for value IDs (for simple displays)
    public var alignedValueIds: [UUID] {
        valueAlignments.map { $0.valueId }
    }

    /// Convenience accessor for measure IDs
    public var targetMeasureIds: [UUID] {
        measureTargets.map { $0.measureId }
    }

    /// Convenience check for active status (no target date or future target)
    public var isActive: Bool {
        guard let target = targetDate else { return true }
        return target > Date()
    }

    /// Convenience computed property for display priority
    public var displayPriority: Int {
        // Higher importance + urgency = higher priority
        return expectationImportance + expectationUrgency
    }
}

// MARK: - CSV Export Support

extension GoalData {
    /// Generate CSV row for this goal
    ///
    /// Provides flat representation suitable for spreadsheet import.
    public var csvRow: [String] {
        [
            id.uuidString.lowercased(),
            title ?? "",
            detailedDescription ?? "",
            freeformNotes ?? "",
            startDate?.ISO8601Format() ?? "",
            targetDate?.ISO8601Format() ?? "",
            actionPlan ?? "",
            String(expectedTermLength ?? 0),
            String(expectationImportance),
            String(expectationUrgency),
            logTime.ISO8601Format(),
            measureTargets.map {
                $0.measureTitle ?? $0.measureId.uuidString.lowercased()
            }.joined(
                separator: ";"),
            alignedValueIds.map { $0.uuidString.lowercased() }.joined(separator: ";"),
        ]
    }

    /// CSV header row
    public static var csvHeader: [String] {
        [
            "ID",
            "Title",
            "Description",
            "Notes",
            "Start Date",
            "Target Date",
            "Action Plan",
            "Expected Term Length",
            "Importance",
            "Urgency",
            "Log Time",
            "Measure Targets",
            "Aligned Values",
        ]
    }
}
