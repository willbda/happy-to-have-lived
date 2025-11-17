//
// PersonalValueData.swift
// Written by Claude Code on 2025-11-16
//
// PURPOSE:
// Canonical personal value data structure that serves both display and export needs.
// Eliminates duplication between PersonalValue (basic entity) and PersonalValueExport (export).
//
// DESIGN:
// - ONE struct for all use cases (not 2+ separate types)
// - Flat structure with PersonalValue fields + denormalized relationships
// - Codable for direct JSON/CSV export
// - Simpler than GoalData/ActionData (fewer relationships)
//

import Foundation

/// Canonical personal value data structure - serves both display and export needs
///
/// **Design Philosophy**:
/// - ONE struct to rule them all (not multiple separate types)
/// - Codable for JSON/CSV export
/// - Sendable for Swift 6 concurrency
/// - Identifiable + Hashable for SwiftUI
/// - Flat structure with minimal denormalization (PersonalValue is simple)
///
/// **Usage**:
/// ```swift
/// // Repository returns this
/// let values = try await repository.fetchAll()
///
/// // Export uses directly
/// let json = try JSONEncoder().encode(values)
///
/// // Views use directly (no transformation needed)
/// List(values) { value in
///     PersonalValueRow(value: value)
/// }
/// ```
public struct PersonalValueData: Identifiable, Hashable, Sendable, Codable {
    // MARK: - Core Identity

    public let id: UUID  // PersonalValue ID (primary key)

    // MARK: - PersonalValue Fields (from personalValues table)

    public let title: String
    public let detailedDescription: String?
    public let freeformNotes: String?
    public let logTime: Date
    public let priority: Int
    public let valueLevel: String  // ValueLevel enum as string for Codable
    public let lifeDomain: String?
    public let alignmentGuidance: String?

    // MARK: - Denormalized Relationship Data

    /// IDs of goals that align with this value (from goalRelevances table)
    public let alignedGoalIds: [UUID]

    /// Convenience count of aligned goals (computed from alignedGoalIds)
    public var alignedGoalCount: Int {
        alignedGoalIds.count
    }

    // MARK: - Initialization

    public init(
        id: UUID,
        title: String,
        detailedDescription: String?,
        freeformNotes: String?,
        logTime: Date,
        priority: Int,
        valueLevel: String,
        lifeDomain: String?,
        alignmentGuidance: String?,
        alignedGoalIds: [UUID]
    ) {
        self.id = id
        self.title = title
        self.detailedDescription = detailedDescription
        self.freeformNotes = freeformNotes
        self.logTime = logTime
        self.priority = priority
        self.valueLevel = valueLevel
        self.lifeDomain = lifeDomain
        self.alignmentGuidance = alignmentGuidance
        self.alignedGoalIds = alignedGoalIds
    }
}

// MARK: - CSV Export Support

extension PersonalValueData {
    /// Generate CSV row for this value
    ///
    /// Provides flat representation suitable for spreadsheet import.
    public var csvRow: [String] {
        [
            id.uuidString,
            title,
            detailedDescription ?? "",
            freeformNotes ?? "",
            String(priority),
            valueLevel,
            lifeDomain ?? "",
            alignmentGuidance ?? "",
            logTime.ISO8601Format(),
            String(alignedGoalCount),
            alignedGoalIds.map { $0.uuidString }.joined(separator: ";")
        ]
    }

    /// CSV header row
    public static var csvHeader: [String] {
        [
            "ID",
            "Title",
            "Description",
            "Notes",
            "Priority",
            "Value Level",
            "Life Domain",
            "Alignment Guidance",
            "Log Time",
            "Aligned Goal Count",
            "Aligned Goal IDs"
        ]
    }
}
