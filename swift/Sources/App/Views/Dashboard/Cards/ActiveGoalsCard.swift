//
// ActiveGoalsCard.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Display top 5 active goals with circular progress indicators on dashboard
// DESIGN: Liquid Glass HIG - .regularMaterial, 16pt corners, 40×40pt progress circles

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct ActiveGoalsCard: View {
    let goals: [GoalData]
    let maxDisplay: Int = 5

    public init(goals: [GoalData]) {
        self.goals = goals
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Active Goals", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(goals.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if goals.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No active goals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            } else {
                // Goals list (top 5)
                VStack(spacing: 12) {
                    ForEach(Array(goals.prefix(maxDisplay))) { goal in
                        GoalRow(goal: goal)
                    }
                }

                if goals.count > maxDisplay {
                    // Show more indicator
                    HStack {
                        Spacer()
                        Text("+\(goals.count - maxDisplay) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Goal Row

@available(iOS 26.0, macOS 26.0, *)
private struct GoalRow: View {
    let goal: GoalData

    var body: some View {
        HStack(spacing: 12) {
            // Progress circle (40×40pt)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: calculateProgress())
                    .stroke(
                        progressGradient(),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(calculateProgress() * 100))")
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }

            // Goal details
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title ?? "Untitled Goal")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Importance badge
                    importanceBadge(goal.importance)

                    // Target date
                    if let targetDate = goal.targetDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(formatDate(targetDate))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func calculateProgress() -> Double {
        // TODO: Calculate actual progress from actions/measurements
        // For now, use a placeholder based on time elapsed
        guard let startDate = goal.startDate,
              let targetDate = goal.targetDate else {
            return 0.0
        }

        let now = Date()
        guard now >= startDate, now <= targetDate else {
            return now < startDate ? 0.0 : 1.0
        }

        let totalDuration = targetDate.timeIntervalSince(startDate)
        let elapsed = now.timeIntervalSince(startDate)

        return min(1.0, max(0.0, elapsed / totalDuration))
    }

    private func progressGradient() -> LinearGradient {
        let progress = calculateProgress()

        switch progress {
        case 0.0..<0.25:
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        case 0.25..<0.50:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case 0.50..<0.75:
            return LinearGradient(colors: [.yellow, .green], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
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
    ActiveGoalsCard(
        goals: [
            GoalData(
                id: UUID(),
                title: "Run a marathon",
                detailedDescription: "Complete 26.2 miles",
                freeformNotes: nil,
                logTime: Date(),
                importance: 9,
                urgency: 7,
                startDate: Date().addingTimeInterval(-30 * 24 * 3600),
                targetDate: Date().addingTimeInterval(60 * 24 * 3600),
                actionPlan: nil,
                expectedTermLength: nil,
                measureTargets: [],
                alignedValues: []
            ),
            GoalData(
                id: UUID(),
                title: "Learn Swift 6",
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date(),
                importance: 6,
                urgency: 5,
                startDate: Date().addingTimeInterval(-15 * 24 * 3600),
                targetDate: Date().addingTimeInterval(75 * 24 * 3600),
                actionPlan: nil,
                expectedTermLength: nil,
                measureTargets: [],
                alignedValues: []
            )
        ]
    )
    .padding()
}
