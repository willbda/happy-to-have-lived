//
// ApproachingObligationsCard.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Display approaching and overdue obligations on dashboard
// DESIGN: Liquid Glass HIG - .regularMaterial, 16pt corners, urgency-based status badges

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct ApproachingObligationsCard: View {
    let obligations: [ObligationWithDetails]
    let daysUntilCalculator: (ObligationWithDetails) -> Int
    let isOverdueCheck: (ObligationWithDetails) -> Bool

    public init(
        obligations: [ObligationWithDetails],
        daysUntilCalculator: @escaping (ObligationWithDetails) -> Int,
        isOverdueCheck: @escaping (ObligationWithDetails) -> Bool
    ) {
        self.obligations = obligations
        self.daysUntilCalculator = daysUntilCalculator
        self.isOverdueCheck = isOverdueCheck
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Obligations", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if !obligations.isEmpty {
                    let overdueCount = obligations.filter(isOverdueCheck).count
                    if overdueCount > 0 {
                        Text("\(overdueCount) overdue")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    } else {
                        Text("\(obligations.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if obligations.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)

                    Text("All caught up!")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)

                    Text("No approaching obligations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            } else {
                // Obligations list
                VStack(spacing: 12) {
                    ForEach(obligations) { obligation in
                        ObligationRow(
                            obligation: obligation,
                            daysUntil: daysUntilCalculator(obligation),
                            isOverdue: isOverdueCheck(obligation)
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

// MARK: - Obligation Row

@available(iOS 26.0, macOS 26.0, *)
private struct ObligationRow: View {
    let obligation: ObligationWithDetails
    let daysUntil: Int
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(statusColor())
                .frame(width: 24)

            // Obligation details
            VStack(alignment: .leading, spacing: 4) {
                Text(obligation.expectation.title ?? "Untitled Obligation")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Deadline
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatDate(obligation.obligation.deadline))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Requested by
                    if let requestedBy = obligation.obligation.requestedBy, !requestedBy.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "person")
                                .font(.caption2)
                            Text(requestedBy)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Importance
                    importanceBadge(obligation.expectation.importance)
                }
            }

            Spacer()

            // Status badge
            statusBadge()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge() -> some View {
        if isOverdue {
            Text("OVERDUE")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red)
                .clipShape(Capsule())
        } else {
            VStack(spacing: 2) {
                Text("\(abs(daysUntil))")
                    .font(.title3.bold())
                    .foregroundStyle(statusColor())

                Text(daysUntil == 0 ? "today" : daysUntil == 1 ? "day" : "days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
        }
    }

    private func statusColor() -> Color {
        if isOverdue {
            return .red
        }

        switch daysUntil {
        case 0:
            return .red  // Due today
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
    ApproachingObligationsCard(
        obligations: [
            ObligationWithDetails(
                obligation: Obligation(
                    id: UUID(),
                    expectationId: UUID(),
                    deadline: Date().addingTimeInterval(-1 * 24 * 3600),
                    requestedBy: "Manager",
                    consequence: "Project delay"
                ),
                expectation: Expectation(
                    id: UUID(),
                    title: "Submit quarterly report",
                    detailedDescription: nil,
                    freeformNotes: nil,
                    logTime: Date(),
                    expectationType: .obligation,
                    expectationImportance: 9,
                    expectationUrgency: 10
                ),
                measures: []
            ),
            ObligationWithDetails(
                obligation: Obligation(
                    id: UUID(),
                    expectationId: UUID(),
                    deadline: Date().addingTimeInterval(2 * 24 * 3600),
                    requestedBy: "Client",
                    consequence: nil
                ),
                expectation: Expectation(
                    id: UUID(),
                    title: "Review pull request",
                    detailedDescription: nil,
                    freeformNotes: nil,
                    logTime: Date(),
                    expectationType: .obligation,
                    expectationImportance: 6,
                    expectationUrgency: 7
                ),
                measures: []
            )
        ],
        daysUntilCalculator: { obligation in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: obligation.obligation.deadline)
            return components.day ?? 0
        },
        isOverdueCheck: { obligation in
            obligation.obligation.deadline < Date()
        }
    )
    .padding()
}
