//
// TimePeriodData.swift
// Written by Claude Code on 2025-11-15
// Renamed from TermData.swift on 2025-11-16
//
// PURPOSE:
// Canonical data type for TimePeriods with GoalTerm planning semantics.
// Serves both display and export needs.
// Replaces separate TermWithPeriod (display) and TermExport (export) types.
//
// ARCHITECTURE:
// Flattens TimePeriod (Abstraction) + GoalTerm (Basic) into single canonical type.
// Follows pattern: Expectation + Goal → GoalData, TimePeriod + GoalTerm → TimePeriodData
//
// ARCHITECTURE PRINCIPLE:
// One canonical data representation with optional transformations for specific needs.
// Repository returns TimePeriodData, consumers transform as needed.
//

import Foundation

/// Canonical time period data structure - serves both display and export needs
///
/// **Design Philosophy**:
/// - ONE canonical type instead of multiple wrappers
/// - Codable for JSON/CSV export
/// - Sendable for Swift 6 concurrency
/// - Identifiable + Hashable for SwiftUI
/// - Flat structure with TimePeriod + GoalTerm data combined
///
/// **Architecture Note**:
/// This type represents TimePeriod (Abstraction) with GoalTerm (Basic) planning semantics.
/// Primary entity: TimePeriod (chronological boundaries)
/// Secondary: GoalTerm (planning state, theme, reflection)
///
/// **Usage**:
/// ```swift
/// // Repository returns this
/// let periods = try await repository.fetchAll()
///
/// // Export uses it directly
/// let json = try JSONEncoder().encode(periods)
///
/// // Views use directly (no transformation needed)
/// List(periods) { period in
///     TermRow(period: period)
/// }
/// ```
public struct TimePeriodData: Identifiable, Hashable, Sendable, Codable {

    // MARK: - TimePeriod Fields (Primary)

    public let timePeriodId: UUID
    public let timePeriodTitle: String?
    public let startDate: Date
    public let endDate: Date

    // MARK: - GoalTerm Fields (Planning Semantics)

    public let id: UUID  // GoalTerm.id (Identifiable conformance)
    public let termNumber: Int
    public let theme: String?
    public let reflection: String?
    public let status: String?  // TermStatus.rawValue

    // MARK: - Associated Goals

    public let assignedGoalIds: [UUID]?

    public init(
        id: UUID,
        termNumber: Int,
        theme: String?,
        reflection: String?,
        status: String?,
        timePeriodId: UUID,
        timePeriodTitle: String?,
        startDate: Date,
        endDate: Date,
        assignedGoalIds: [UUID]?
    ) {
        self.id = id
        self.termNumber = termNumber
        self.theme = theme
        self.reflection = reflection
        self.status = status
        self.timePeriodId = timePeriodId
        self.timePeriodTitle = timePeriodTitle
        self.startDate = startDate
        self.endDate = endDate
        self.assignedGoalIds = assignedGoalIds
    }
}

// MARK: - Convenience Properties

extension TimePeriodData {
    /// Computed TermStatus enum from string
    public var termStatus: TermStatus? {
        guard let statusString = status else { return nil }
        return TermStatus(rawValue: statusString)
    }
}
