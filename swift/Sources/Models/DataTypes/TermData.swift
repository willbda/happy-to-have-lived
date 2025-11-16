//
// TermData.swift
// Written by Claude Code on 2025-11-15
//
// PURPOSE:
// Canonical data type for Terms - serves both display and export needs.
// Replaces separate TermWithPeriod (display) and TermExport (export) types.
//
// ARCHITECTURE PRINCIPLE:
// One canonical data representation with optional transformations for specific needs.
// Repository returns TermData, consumers transform as needed.
//

import Foundation

/// Canonical term data structure - serves both display and export needs
///
/// **Design Philosophy**:
/// - ONE canonical type instead of multiple wrappers
/// - Codable for JSON/CSV export
/// - Sendable for Swift 6 concurrency
/// - Identifiable + Hashable for SwiftUI
/// - Flat structure with TimePeriod data inlined
///
/// **Usage**:
/// ```swift
/// // Repository returns this
/// let terms = try await repository.fetchAll()
///
/// // Export uses it directly
/// let json = try JSONEncoder().encode(terms)
///
/// // Views can transform if they need nested entities
/// let withPeriods = terms.map { $0.asWithPeriod }
/// ```
public struct TermData: Identifiable, Hashable, Sendable, Codable {

    // MARK: - Term Fields

    public let id: UUID
    public let termNumber: Int
    public let theme: String?
    public let reflection: String?
    public let status: String?  // TermStatus.rawValue

    // MARK: - TimePeriod Fields (Inlined)

    public let timePeriodId: UUID
    public let timePeriodTitle: String?
    public let startDate: Date
    public let endDate: Date

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

extension TermData {
    /// Computed TermStatus enum from string
    public var termStatus: TermStatus? {
        guard let statusString = status else { return nil }
        return TermStatus(rawValue: statusString)
    }
}

// MARK: - Backward Compatibility Transformation

extension TermData {
    /// Transform to TermWithPeriod for views that need nested entity structure
    ///
    /// **When to use**: SwiftUI views that bind to nested entities (GoalTerm, TimePeriod)
    /// **When NOT to use**: Export, CSV formatting, most list views (use TermData directly)
    ///
    /// **Note**: This creates entities from the flat structure.
    /// Full TimePeriod metadata (title, detailedDescription, notes, logTime) is included.
    public var asWithPeriod: TermWithPeriod {
        let term = GoalTerm(
            timePeriodId: timePeriodId,
            termNumber: termNumber,
            theme: theme,
            reflection: reflection,
            status: termStatus,
            id: id
        )

        let period = TimePeriod(
            title: timePeriodTitle,
            detailedDescription: nil,  // Not available in flat structure
            freeformNotes: nil,         // Not available in flat structure
            startDate: startDate,
            endDate: endDate,
            logTime: startDate,         // Use startDate as placeholder
            id: timePeriodId
        )

        return TermWithPeriod(term: term, timePeriod: period)
    }
}
