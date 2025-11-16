//
// ActionData.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Canonical data type for Actions - serves both display and export needs.
// Replaces separate ActionWithDetails (display) and ActionExport (export) types.
//
// ARCHITECTURE PRINCIPLE:
// One canonical data representation with optional transformations for specific needs.
// Repository returns ActionData, consumers transform as needed.
//

import Foundation

/// Canonical action data structure - serves both display and export needs
///
/// **Design Philosophy**:
/// - ONE canonical type instead of multiple wrappers
/// - Codable for JSON/CSV export
/// - Sendable for Swift 6 concurrency
/// - Identifiable + Hashable for SwiftUI
/// - Flat structure (simple nested structs, no complex entity graphs)
///
/// **Usage**:
/// ```swift
/// // Repository returns this
/// let actions = try await repository.fetchAll()
///
/// // Export uses it directly
/// let json = try JSONEncoder().encode(actions)
///
/// // Views can transform if they need nested entities
/// let details = actions.map { $0.asDetails }
/// ```
public struct ActionData: Identifiable, Hashable, Sendable, Codable {

    // MARK: - Core Action Fields

    public let id: UUID
    public let title: String?
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let logTime: Date
    public let durationMinutes: Double?
    public let startTime: Date?

    // MARK: - Denormalized Measurements

    /// Flat measurement data (no nested MeasuredAction entities)
    ///
    /// Contains all data needed for display:
    /// - measureTitle, measureUnit, measureType for formatting
    /// - value for the actual measurement
    /// - id and createdAt for tracking
    public struct Measurement: Identifiable, Hashable, Sendable, Codable {
        public let id: UUID              // measuredAction.id
        public let measureId: UUID
        public let measureTitle: String?
        public let measureUnit: String
        public let measureType: String
        public let value: Double
        public let createdAt: Date

        public init(
            id: UUID,
            measureId: UUID,
            measureTitle: String?,
            measureUnit: String,
            measureType: String,
            value: Double,
            createdAt: Date
        ) {
            self.id = id
            self.measureId = measureId
            self.measureTitle = measureTitle
            self.measureUnit = measureUnit
            self.measureType = measureType
            self.value = value
            self.createdAt = createdAt
        }
    }

    public let measurements: [Measurement]

    // MARK: - Denormalized Contributions

    /// Flat contribution data (no nested Goal entities)
    ///
    /// Includes goalTitle for display convenience (from JOIN with expectations table).
    /// If full Goal details needed, fetch separately by goalId.
    public struct Contribution: Identifiable, Hashable, Sendable, Codable {
        public let id: UUID              // contribution.id
        public let goalId: UUID
        public let goalTitle: String?    // From JOIN with expectations
        public let contributionAmount: Double?
        public let measureId: UUID?
        public let createdAt: Date

        public init(
            id: UUID,
            goalId: UUID,
            goalTitle: String?,
            contributionAmount: Double?,
            measureId: UUID?,
            createdAt: Date
        ) {
            self.id = id
            self.goalId = goalId
            self.goalTitle = goalTitle
            self.contributionAmount = contributionAmount
            self.measureId = measureId
            self.createdAt = createdAt
        }
    }

    public let contributions: [Contribution]

    public init(
        id: UUID,
        title: String?,
        detailedDescription: String?,
        freeformNotes: String?,
        logTime: Date,
        durationMinutes: Double?,
        startTime: Date?,
        measurements: [Measurement],
        contributions: [Contribution]
    ) {
        self.id = id
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.logTime = logTime
        self.durationMinutes = durationMinutes
        self.startTime = startTime
        self.measurements = measurements
        self.contributions = contributions
    }
}

// MARK: - Convenience Properties

extension ActionData {
    /// Convenience accessor for goal IDs (for simple list displays)
    ///
    /// Useful for CSV export or views that just need to show "Contributing to 3 goals"
    public var contributingGoalIds: [UUID] {
        contributions.map { $0.goalId }
    }
}

// MARK: - Backward Compatibility Transformation

extension ActionData {
    /// Transform to ActionWithDetails for views that need nested entity structure
    ///
    /// **When to use**: SwiftUI views that bind to nested entities (ActionMeasurement, ActionContribution)
    /// **When NOT to use**: Export, CSV formatting, most list views (use ActionData directly)
    ///
    /// **Note**: This creates placeholder entities:
    /// - Measure: Only includes fields present in ActionData.Measurement (no detailedDescription, notes, etc.)
    /// - Goal: Minimal placeholder with just ID and title (no expectation data, dates, etc.)
    ///
    /// If you need full Measure or Goal details, fetch them separately from repositories.
    public var asDetails: ActionWithDetails {
        let action = Action(
            title: title,
            detailedDescription: detailedDescription,
            freeformNotes: freeformNotes,
            durationMinutes: durationMinutes,
            startTime: startTime,
            logTime: logTime,
            id: id
        )

        let actionMeasurements = measurements.map { m in
            let measuredAction = MeasuredAction(
                actionId: id,
                measureId: m.measureId,
                value: m.value,
                createdAt: m.createdAt,
                id: m.id
            )

            let measure = Measure(
                unit: m.measureUnit,
                measureType: m.measureType,
                title: m.measureTitle,
                detailedDescription: nil,       // Not available in flat structure
                freeformNotes: nil,             // Not available in flat structure
                canonicalUnit: nil,             // Not available in flat structure
                conversionFactor: nil,          // Not available in flat structure
                logTime: m.createdAt,           // Use createdAt as placeholder
                id: m.measureId
            )

            return ActionMeasurement(measuredAction: measuredAction, measure: measure)
        }

        let actionContributions = contributions.map { c in
            let contribution = ActionGoalContribution(
                actionId: id,
                goalId: c.goalId,
                contributionAmount: c.contributionAmount,
                measureId: c.measureId,
                createdAt: c.createdAt,
                id: c.id
            )

            // Placeholder goal (just ID - no expectation data)
            // If view needs full Goal details, it should fetch from GoalRepository
            let goal = Goal(
                expectationId: UUID(),          // Placeholder
                startDate: nil,
                targetDate: nil,
                actionPlan: nil,
                expectedTermLength: nil,
                id: c.goalId
            )

            return ActionContribution(contribution: contribution, goal: goal)
        }

        return ActionWithDetails(
            action: action,
            measurements: actionMeasurements,
            contributions: actionContributions
        )
    }
}
