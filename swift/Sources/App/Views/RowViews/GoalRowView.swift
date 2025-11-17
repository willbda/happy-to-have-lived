//
// GoalRowView.swift
// Written by Claude Code on 2025-11-03
// Updated by Claude Code on 2025-11-16 - Migrated to canonical GoalData
//
// PURPOSE: Display row for Goal with multi-metric progress and value alignment
// RECEIVES: GoalData from parent (canonical flat structure)
// DISPLAYS: Title, dates, progress, value badges, status
//

import Models
import SwiftUI

/// Row view for goal display in lists
///
/// PATTERN: Receives canonical GoalData (flat structure, no nested entities)
/// NO DATABASE ACCESS: All data passed via GoalData
/// DISPLAYS:
/// - Title (from flattened expectation fields)
/// - Date range (from goal fields)
/// - Progress indicator (multi-metric targets)
/// - Value alignment badges (from denormalized value alignments)
/// - Status indicator (on track, behind, completed)
public struct GoalRowView: View {
    let goal: GoalData

    public init(goal: GoalData) {
        self.goal = goal
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = goal.startDate, let end = goal.targetDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let end = goal.targetDate {
            return "Due \(formatter.string(from: end))"
        } else {
            return "No due date"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and importance/urgency
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title ?? "Untitled Goal")
                        .font(.headline)

                    if let description = goal.detailedDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Importance/Urgency badges
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(goal.expectationImportance)")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)

                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text("\(goal.expectationUrgency)")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }
            }

            // Progress (if metrics exist)
            if !goal.measureTargets.isEmpty {
                ProgressIndicator(
                    measureTargets: goal.measureTargets,
                    actualProgress: [:],  // TODO: Calculate actual progress in Phase 2
                    displayMode: .compact
                )
            }

            // Value alignments
            if !goal.valueAlignments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(goal.valueAlignments) { alignment in
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                Text(alignment.valueTitle)
                                    .font(.caption)
                                if let strength = alignment.alignmentStrength {
                                    Text("(\(strength))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.2))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Date range
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dateRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("With Metrics and Values") {
    List {
        GoalRowView(
            goal: GoalData(
                id: UUID(),
                startDate: Date(),
                targetDate: Calendar.current.date(byAdding: .weekOfYear, value: 10, to: Date()),
                actionPlan: "Run 3x per week",
                expectedTermLength: 10,
                expectationId: UUID(),
                title: "Spring into Running",
                detailedDescription: "Build running habit and endurance",
                freeformNotes: nil,
                expectationImportance: 8,
                expectationUrgency: 5,
                logTime: Date(),
                measureTargets: [
                    GoalData.MeasureTarget(
                        id: UUID(),
                        measureId: UUID(),
                        measureTitle: "Distance",
                        measureUnit: "km",
                        measureType: "distance",
                        targetValue: 120,
                        freeformNotes: nil,
                        createdAt: Date()
                    )
                ],
                valueAlignments: [
                    GoalData.ValueAlignment(
                        id: UUID(),
                        valueId: UUID(),
                        valueTitle: "Health",
                        alignmentStrength: 9,
                        relevanceNotes: nil,
                        createdAt: Date()
                    )
                ],
                termAssignment: nil
            )
        )
    }
}

#Preview("Minimal Goal") {
    List {
        GoalRowView(
            goal: GoalData(
                id: UUID(),
                startDate: nil,
                targetDate: Date(),
                actionPlan: nil,
                expectedTermLength: nil,
                expectationId: UUID(),
                title: "Simple Goal",
                detailedDescription: nil,
                freeformNotes: nil,
                expectationImportance: 5,
                expectationUrgency: 5,
                logTime: Date(),
                measureTargets: [],
                valueAlignments: [],
                termAssignment: nil
            )
        )
    }
}
