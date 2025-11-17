//
// TermRowView.swift
// Written by Claude Code on 2025-11-02
// Updated by Claude Code on 2025-11-16 - Migrated to canonical TimePeriodData
//
// PURPOSE: Row display for Term with TimePeriod details
// ARCHITECTURE: Clean display view - receives canonical TimePeriodData
//

import Models
import SwiftUI

/// Row view for displaying a Term with TimePeriod details.
///
/// ARCHITECTURE: Receives canonical TimePeriodData (flat structure)
/// - Accepts TimePeriodData from parent (combines GoalTerm + TimePeriod data)
/// - No N+1 queries - parent fetches all data in single query
/// - Pure display logic - no database access
/// - Displays term number, title, and dates
///
/// PATTERN: Based on PersonalValuesRowView
/// - Simple display, no business logic
/// - BadgeView for term number
/// - Shows TimePeriod title and date range
public struct TermRowView: View {
    let timePeriod: TimePeriodData

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Term-specific: termNumber badge
                BadgeView(badge: Badge(text: "Term \(timePeriod.termNumber)", color: .blue))

                // Generic: TimePeriod title or fallback
                Text(timePeriod.timePeriodTitle ?? "Term \(timePeriod.termNumber)")
                    .font(.headline)

                // Generic: TimePeriod dates
                Text("\(timePeriod.startDate.formatted(date: .abbreviated, time: .omitted)) - \(timePeriod.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    let samplePeriodData = TimePeriodData(
        id: UUID(),
        termNumber: 5,
        theme: "Health & Growth",
        reflection: nil,
        status: "active",
        timePeriodId: UUID(),
        timePeriodTitle: "Spring Term",
        startDate: Date(),
        endDate: Date().addingTimeInterval(60 * 60 * 24 * 70), // 10 weeks
        assignedGoalIds: nil
    )

    return List {
        TermRowView(timePeriod: samplePeriodData)
    }
}