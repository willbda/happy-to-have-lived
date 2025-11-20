//
// RecentActionsCard.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Display recent actions with measurement badges and goal contribution chips
// KEY FEATURE: Blue chips showing which goals each action advances
// DESIGN: Liquid Glass HIG - .regularMaterial, 16pt corners, green measurement badges, blue goal chips

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct RecentActionsCard: View {
    let actions: [ActionData]
    let maxDisplay: Int = 10

    public init(actions: [ActionData]) {
        self.actions = actions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Recent Actions", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(actions.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if actions.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No recent actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            } else {
                // Actions list (last 10)
                VStack(spacing: 12) {
                    ForEach(Array(actions.prefix(maxDisplay))) { action in
                        ActionRow(action: action)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Action Row

@available(iOS 26.0, macOS 26.0, *)
private struct ActionRow: View {
    let action: ActionData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Action title and timestamp
            HStack {
                Text(action.title ?? "Untitled Action")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(formatTimestamp(action.logTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Measurements (green badges)
            if !action.measurements.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(action.measurements) { measurement in
                        MeasurementBadge(measurement: measurement)
                    }
                }
            }

            // Goal contributions (blue chips) - KEY FEATURE!
            if !action.contributions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(action.contributions) { contribution in
                        GoalContributionChip(contribution: contribution)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Measurement Badge (Green)

@available(iOS 26.0, macOS 26.0, *)
private struct MeasurementBadge: View {
    let measurement: ActionData.MeasurementData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "ruler")
                .font(.caption2)

            Text("\(formatValue(measurement.value)) \(measurement.measureUnit)")
                .font(.caption.bold())
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.green.opacity(0.2))
        .clipShape(Capsule())
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Goal Contribution Chip (Blue) - KEY COMPONENT!

@available(iOS 26.0, macOS 26.0, *)
private struct GoalContributionChip: View {
    let contribution: ActionData.ContributionData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "target")
                .font(.caption2)

            // Use goalTitle from ContributionData (already available!)
            Text(contribution.goalTitle ?? "Goal")
                .font(.caption.bold())
                .lineLimit(1)

            // Show contribution amount if present
            if let amount = contribution.contributionAmount {
                Text("(\(formatContribution(amount)))")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.2))
        .clipShape(Capsule())
    }

    private func formatContribution(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.1f", amount)
        }
    }
}

// MARK: - Flow Layout (for wrapping badges/chips)

@available(iOS 26.0, macOS 26.0, *)
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

#Preview {
    RecentActionsCard(
        actions: [
            ActionData(
                id: UUID(),
                title: "Morning run",
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date(),
                durationMinutes: 45,
                startTime: Date(),
                measurements: [
                    ActionData.MeasurementData(
                        id: UUID(),
                        value: 5.2,
                        createdAt: Date(),
                        measureId: UUID(),
                        measureTitle: "Distance",
                        measureUnit: "km",
                        measureType: "distance"
                    )
                ],
                contributions: [
                    ActionData.ContributionData(
                        id: UUID(),
                        goalId: UUID(),
                        goalTitle: "Run a marathon",
                        contributionAmount: 5.2,
                        measureId: UUID(),
                        createdAt: Date()
                    ),
                    ActionData.ContributionData(
                        id: UUID(),
                        goalId: UUID(),
                        goalTitle: "Improve cardio fitness",
                        contributionAmount: nil,
                        measureId: nil,
                        createdAt: Date()
                    )
                ]
            ),
            ActionData(
                id: UUID(),
                title: "Swift 6 tutorial completed",
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date().addingTimeInterval(-3600),
                durationMinutes: 120,
                startTime: nil,
                measurements: [],
                contributions: [
                    ActionData.ContributionData(
                        id: UUID(),
                        goalId: UUID(),
                        goalTitle: "Learn Swift 6",
                        contributionAmount: nil,
                        measureId: nil,
                        createdAt: Date()
                    )
                ]
            )
        ]
    )
    .padding()
}
