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
/// // Views use directly (no transformation needed)
/// List(actions) { action in
///     ActionRow(action: action)
/// }
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
