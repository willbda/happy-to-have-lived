//
// ActionRowView.swift
// Specialized row view for displaying actions in lists
//
// Written by Claude Code on 2025-11-01
// Updated by Claude Code on 2025-11-02 (ActionWithDetails pattern)
// Updated by Claude Code on 2025-11-16 - Migrated to canonical ActionData
//
// PURPOSE:
// Displays Action with measurements and goal contributions.
// Receives ActionData from parent (canonical flat structure).

import SwiftUI
import Models
import Services

// MARK: - ActionRowView

/// Displays an action in a list with measurements and goal contributions
///
/// **Pattern**: Receives ActionData (canonical type)
/// **No database access** - all data passed from parent
///
/// **Usage**:
/// ```swift
/// ForEach(actions) { action in
///     ActionRowView(action: action)
/// }
/// ```
public struct ActionRowView: View {
    let action: ActionData

    public init(action: ActionData) {
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title only (relative timestamp removed for clarity)
            // Previously displayed: logTime with .relative style ("2 hours ago")
            // Removed as it was found to be distracting rather than helpful
            Text(action.title ?? "Untitled Action")
                .font(.headline)

            // Measurements (if any)
            if !action.measurements.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "ruler")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(measurementsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Duration (if tracked AND no time measurement exists)
            // Hide duration if there's already a time-based measurement to avoid redundancy
            if let duration = action.durationMinutes,
               duration > 0,
               !hasTimeMeasurement {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(Int(duration)) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Goal contributions badge (if any)
            if !action.contributions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("\(action.contributions.count) goal\(action.contributions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            // Description (if present)
            if let description = action.detailedDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    /// Checks if any measurement is time-based
    ///
    /// Used to avoid redundant display when both durationMinutes and time measurements exist.
    /// Time-based units: minutes, min, hours, hrs, seconds, secs
    private var hasTimeMeasurement: Bool {
        let timeUnits = ["minutes", "min", "hours", "hrs", "hour", "seconds", "secs", "second"]
        return action.measurements.contains { measurement in
            let unit = measurement.measureUnit.lowercased()
            return timeUnits.contains(unit) || measurement.measureType == "time"
        }
    }

    /// Formats measurements as comma-separated list
    /// Example: "5.2 km, 28 min, 3 occasions"
    private var measurementsText: String {
        action.measurements
            .map { measurement in
                let value = measurement.value
                let unit = measurement.measureUnit

                // Format value (no decimals if whole number)
                let valueStr = value.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", value)
                    : String(format: "%.1f", value)

                return "\(valueStr) \(unit)"
            }
            .joined(separator: ", ")
    }
}

