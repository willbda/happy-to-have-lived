//
// ObligationRowView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Row view for displaying a single obligation in a list
// PATTERN: Simple presentational view (no state, no actions)
//

import Models
import Services
import SwiftUI

/// Row view for displaying a single obligation
///
/// **PATTERN**: Presentational component (stateless)
/// **DATA**: ObligationWithDetails from parent
/// **DISPLAY**: Title, deadline, requested by, importance/urgency
///
public struct ObligationRowView: View {
    let obligation: ObligationWithDetails

    public init(obligation: ObligationWithDetails) {
        self.obligation = obligation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(obligation.expectation.title ?? "Untitled Obligation")
                .font(.headline)

            // Deadline
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(obligation.obligation.deadline, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Requested By (if provided)
            if let requestedBy = obligation.obligation.requestedBy, !requestedBy.isEmpty {
                HStack {
                    Image(systemName: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(requestedBy)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Importance/Urgency indicators
            HStack(spacing: 12) {
                // Importance
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(obligation.expectation.expectationImportance)")
                        .font(.caption)
                }
                .foregroundStyle(.orange)

                // Urgency
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("\(obligation.expectation.expectationUrgency)")
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
