//
// UpcomingMilestonesCard.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Display upcoming milestones (next 7 days) on dashboard
// DESIGN: Liquid Glass HIG - .regularMaterial, 16pt corners, "days until" badges

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct UpcomingMilestonesCard: View {
    let milestones: [MilestoneWithDetails]
    let daysUntilCalculator: (MilestoneWithDetails) -> Int

    public init(
        milestones: [MilestoneWithDetails],
        daysUntilCalculator: @escaping (MilestoneWithDetails) -> Int
    ) {
        self.milestones = milestones
        self.daysUntilCalculator = daysUntilCalculator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Upcoming Milestones", systemImage: "flag.checkered")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(milestones.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if milestones.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No upcoming milestones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            } else {
                // Milestones list
                VStack(spacing: 12) {
                    ForEach(milestones) { milestone in
                        MilestoneRow(
                            milestone: milestone,
                            daysUntil: daysUntilCalculator(milestone)
                        )
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Milestone Row

@available(iOS 26.0, macOS 26.0, *)
private struct MilestoneRow: View {
    let milestone: MilestoneWithDetails
    let daysUntil: Int

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "flag.fill")
                .font(.title3)
                .foregroundStyle(urgencyColor())
                .frame(width: 24)

            // Milestone details
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.expectation.title ?? "Untitled Milestone")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Target date
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatDate(milestone.milestone.targetDate))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Importance
                    importanceBadge(milestone.expectation.importance)
                }
            }

            Spacer()

            // Days until badge
            daysUntilBadge(daysUntil)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func daysUntilBadge(_ days: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(abs(days))")
                .font(.title3.bold())
                .foregroundStyle(urgencyColor())

            Text(days == 0 ? "today" : days == 1 ? "day" : "days")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 50)
    }

    private func urgencyColor() -> Color {
        switch daysUntil {
        case ...0:
            return .red  // Today or past
        case 1...2:
            return .orange  // Very soon (1-2 days)
        case 3...4:
            return .yellow  // Soon (3-4 days)
        default:
            return .blue  // Later (5+ days)
        }
    }

    @ViewBuilder
    private func importanceBadge(_ importance: Int) -> some View {
        let color: Color = importance >= 8 ? .red : importance >= 5 ? .orange : .blue

        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
            Text("\(importance)")
                .font(.caption2.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.2))
        .clipShape(Capsule())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    UpcomingMilestonesCard(
        milestones: [
            MilestoneWithDetails(
                milestone: Milestone(
                    id: UUID(),
                    expectationId: UUID(),
                    targetDate: Date().addingTimeInterval(1 * 24 * 3600)
                ),
                expectation: Expectation(
                    id: UUID(),
                    title: "Complete first 10K run",
                    detailedDescription: nil,
                    freeformNotes: nil,
                    logTime: Date(),
                    expectationType: .milestone,
                    expectationImportance: 8,
                    expectationUrgency: 9
                ),
                measures: []
            ),
            MilestoneWithDetails(
                milestone: Milestone(
                    id: UUID(),
                    expectationId: UUID(),
                    targetDate: Date().addingTimeInterval(5 * 24 * 3600)
                ),
                expectation: Expectation(
                    id: UUID(),
                    title: "Ship SwiftUI feature",
                    detailedDescription: nil,
                    freeformNotes: nil,
                    logTime: Date(),
                    expectationType: .milestone,
                    expectationImportance: 7,
                    expectationUrgency: 6
                ),
                measures: []
            )
        ],
        daysUntilCalculator: { milestone in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: milestone.milestone.targetDate)
            return components.day ?? 0
        }
    )
    .padding()
}
