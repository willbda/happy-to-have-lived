//
// ActiveTermCard.swift
// Written by Claude Code on 2025-11-20
//
// PURPOSE: Display current active term with progress bar on dashboard
// DESIGN: Liquid Glass HIG - .regularMaterial, 16pt corners

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct ActiveTermCard: View {
    let term: TimePeriodData?
    let progress: Double
    let daysRemaining: Int

    public init(term: TimePeriodData?, progress: Double, daysRemaining: Int) {
        self.term = term
        self.progress = progress
        self.daysRemaining = daysRemaining
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Current Term", systemImage: "calendar.badge.clock")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let term = term {
                    Text("Term \(term.termNumber)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            if let term = term {
                // Term theme
                if let theme = term.theme, !theme.isEmpty {
                    Text(theme)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                // Date range
                HStack {
                    Text(formatDate(term.startDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("→")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(formatDate(term.endDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(daysRemaining) days left")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

            } else {
                // No active term
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No active term")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 16) {
        // With active term
        ActiveTermCard(
            term: TimePeriodData(
                id: UUID(),
                termNumber: 1,
                theme: "Foundation Building",
                reflection: nil,
                status: "active",
                timePeriodId: UUID(),
                timePeriodTitle: "Q1 2025",
                startDate: Date().addingTimeInterval(-30 * 24 * 3600),
                endDate: Date().addingTimeInterval(60 * 24 * 3600),
                detailedDescription: nil,
                freeformNotes: nil,
                logTime: Date(),
                assignedGoalIds: nil
            ),
            progress: 0.33,
            daysRemaining: 60
        )

        // No active term
        ActiveTermCard(
            term: nil,
            progress: 0.0,
            daysRemaining: 0
        )
    }
    .padding()
}
