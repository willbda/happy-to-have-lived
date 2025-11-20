//
// MilestoneRowView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Row view for displaying a single milestone in a list
// PATTERN: Simple presentational view (no state, no actions)
//

import Models
import Services
import SwiftUI

/// Row view for displaying a single milestone
///
/// **PATTERN**: Presentational component (stateless)
/// **DATA**: MilestoneWithDetails from parent
/// **DISPLAY**: Title, target date, importance/urgency
///
public struct MilestoneRowView: View {
    let milestone: MilestoneWithDetails

    public init(milestone: MilestoneWithDetails) {
        self.milestone = milestone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(milestone.expectation.title ?? "Untitled Milestone")
                .font(.headline)

            // Target Date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(milestone.milestone.targetDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Importance/Urgency indicators
            HStack(spacing: 12) {
                // Importance
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(milestone.expectation.expectationImportance)")
                        .font(.caption)
                }
                .foregroundStyle(.orange)

                // Urgency
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("\(milestone.expectation.expectationUrgency)")
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
