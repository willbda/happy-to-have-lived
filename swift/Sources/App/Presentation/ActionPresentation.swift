//
// ActionPresentation.swift
// Written by Claude Code on 2025-11-21
//
// PURPOSE: Presentation helpers for Action display
//
// PATTERN: Separate presentation layer from domain models
// - Keeps domain models pure (ActionData has no UI dependencies)
// - Single source of truth for visual presentation
// - Reusable across all views (HomeView, ActionsListView, ActionDetailView)
// - Testable independently
//

import SwiftUI
import Models

/// Presentation helpers for Action display
public struct ActionPresentation {

    /// Get icon for an action based on its measurements
    ///
    /// **Algorithm**: Uses first measurement's unit, falls back to checkmark
    /// **Use Case**: Action row icons, list displays
    ///
    /// **Example**:
    /// ```swift
    /// let icon = ActionPresentation.icon(for: actionData)
    /// Image(systemName: icon)
    /// ```
    public static func icon(for action: ActionData) -> String {
        if let firstMeasurement = action.measurements.first {
            return MeasurePresentation.icon(for: firstMeasurement.measureUnit)
        }
        return "checkmark.circle.fill"
    }
}

// MARK: - Convenience Extensions

extension ActionData {
    /// Icon for this action (delegates to ActionPresentation)
    public var icon: String {
        ActionPresentation.icon(for: self)
    }

    /// Formatted measurement display
    ///
    /// **Returns**: Measurement value + unit, duration formatted, or empty string
    ///
    /// **Example**:
    /// ```swift
    /// Text(action.formattedMeasurement)  // "5 km" or "1h 30m" or ""
    /// ```
    public var formattedMeasurement: String {
        // Priority 1: First measurement
        if let firstMeasurement = measurements.first {
            let value = Int(firstMeasurement.value)
            return "\(value) \(firstMeasurement.measureUnit)"
        }

        // Priority 2: Duration
        if let duration = durationMinutes {
            let hours = Int(duration) / 60
            let minutes = Int(duration) % 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }

        // No measurement data
        return ""
    }

    /// First contributing goal title (for display)
    ///
    /// **Use Case**: Show goal context in action rows
    /// **Returns**: Goal title or nil if no contributions
    ///
    /// **Example**:
    /// ```swift
    /// if let goalTitle = action.goalTitle(from: dataStore) {
    ///     Text(goalTitle)
    /// }
    /// ```
    @MainActor
    public func goalTitle(from dataStore: DataStore) -> String? {
        guard let firstContribution = contributions.first else { return nil }
        return dataStore.goals.first(where: { $0.id == firstContribution.goalId })?.title
    }
}
