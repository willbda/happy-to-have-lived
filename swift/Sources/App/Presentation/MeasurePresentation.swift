//
// MeasurePresentation.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Presentation catalog for Measure display (SF Symbol mapping)
//
// CONFIGURATION-DRIVEN PATTERN:
// - Add new measure types by updating catalog (no code changes in views)
// - Centralized mapping ensures consistency across app
// - Category grouping enables future filtering/organization
//
// DESIGN DECISIONS:
// - Dictionary lookup O(1) vs switch statement
// - Case-insensitive matching (user can enter "KM" or "km")
// - Fallback icon for unknown units ("checkmark.circle.fill")
//

import Foundation

/// Presentation catalog for Measure display (SF Symbol mapping)
public struct MeasurePresentation: Sendable {
    public let unit: String
    public let icon: String
    public let category: String

    private static let catalog: [String: MeasurePresentation] = [
        // Distance
        "km": .init(unit: "km", icon: "figure.run", category: "distance"),
        "miles": .init(unit: "miles", icon: "figure.run", category: "distance"),
        "mi": .init(unit: "mi", icon: "figure.run", category: "distance"),
        "m": .init(unit: "m", icon: "figure.run", category: "distance"),

        // Weight
        "kg": .init(unit: "kg", icon: "dumbbell.fill", category: "weight"),
        "lbs": .init(unit: "lbs", icon: "dumbbell.fill", category: "weight"),
        "lb": .init(unit: "lb", icon: "dumbbell.fill", category: "weight"),

        // Reading
        "pages": .init(unit: "pages", icon: "book.fill", category: "reading"),
        "page": .init(unit: "page", icon: "book.fill", category: "reading"),

        // Time
        "min": .init(unit: "min", icon: "clock.fill", category: "time"),
        "minutes": .init(unit: "minutes", icon: "clock.fill", category: "time"),
        "hours": .init(unit: "hours", icon: "clock.fill", category: "time"),
        "hour": .init(unit: "hour", icon: "clock.fill", category: "time"),
        "hr": .init(unit: "hr", icon: "clock.fill", category: "time"),

        // Exercise
        "reps": .init(unit: "reps", icon: "figure.strengthtraining.traditional", category: "exercise"),
        "sets": .init(unit: "sets", icon: "figure.strengthtraining.traditional", category: "exercise")
    ]

    /// Get SF Symbol icon for measure unit
    ///
    /// **Pattern**: Dictionary lookup with fallback
    /// **Case-insensitive**: "KM" → "figure.run" (same as "km")
    /// **Fallback**: Unknown units → "checkmark.circle.fill"
    ///
    /// **Example**:
    /// ```swift
    /// let icon = MeasurePresentation.icon(for: "km")  // "figure.run"
    /// let icon = MeasurePresentation.icon(for: "lbs") // "dumbbell.fill"
    /// let icon = MeasurePresentation.icon(for: "xyz") // "checkmark.circle.fill" (fallback)
    /// ```
    public static func icon(for unit: String) -> String {
        catalog[unit.lowercased()]?.icon ?? "checkmark.circle.fill"
    }

    /// Get category for measure unit
    ///
    /// **Categories**: distance, weight, reading, time, exercise, general
    /// **Use Case**: Future filtering or grouping in measure picker
    ///
    /// **Example**:
    /// ```swift
    /// let category = MeasurePresentation.category(for: "km")  // "distance"
    /// let category = MeasurePresentation.category(for: "pages") // "reading"
    /// ```
    public static func category(for unit: String) -> String {
        catalog[unit.lowercased()]?.category ?? "general"
    }
}
