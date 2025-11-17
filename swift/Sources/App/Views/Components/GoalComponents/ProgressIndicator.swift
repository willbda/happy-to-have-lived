//
// ProgressIndicator.swift
// Written by Claude Code on 2025-11-03
// Updated by Claude Code on 2025-11-16 - Migrated to canonical GoalData.MeasureTarget
//
// PURPOSE: Visual indicator for goal progress (multi-metric)
// USAGE: Used in GoalRowView to show progress toward targets
// DISPLAYS: Progress bars per metric + overall completion %
//

import Models
import SwiftUI

/// Progress visualization for multi-metric goals
///
/// Shows progress toward each metric target:
/// - "Running: 87 / 120 km (72.5%)"
/// - "Sessions: 18 / 30 (60%)"
/// - Overall: 66% complete
///
/// PATTERN: Reusable component for row and detail views
public struct ProgressIndicator: View {
    let measureTargets: [GoalData.MeasureTarget]
    let actualProgress: [UUID: Double]  // measureId -> actual value
    let displayMode: DisplayMode

    public enum DisplayMode {
        case compact  // Single line summary (for row views)
        case detailed // Multiple progress bars (for detail views)
    }

    public init(
        measureTargets: [GoalData.MeasureTarget],
        actualProgress: [UUID: Double] = [:],
        displayMode: DisplayMode = .compact
    ) {
        self.measureTargets = measureTargets
        self.actualProgress = actualProgress
        self.displayMode = displayMode
    }

    /// Calculate overall progress as average of all metrics
    private var overallProgress: Double {
        guard !measureTargets.isEmpty else { return 0 }

        let progressValues = measureTargets.compactMap { target -> Double? in
            guard let actual = actualProgress[target.measureId],
                  target.targetValue > 0 else {
                return nil
            }
            return min(actual / target.targetValue, 1.0)
        }

        guard !progressValues.isEmpty else { return 0 }
        return progressValues.reduce(0, +) / Double(progressValues.count)
    }

    public var body: some View {
        switch displayMode {
        case .compact:
            compactView
        case .detailed:
            detailedView
        }
    }

    /// Compact view for list rows
    private var compactView: some View {
        HStack {
            Image(systemName: overallProgress >= 1.0 ? "checkmark.circle.fill" : "circle.fill")
                .foregroundStyle(progressColor)
                .font(.caption)

            Text("\(Int(overallProgress * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !measureTargets.isEmpty {
                Text("(\(measureTargets.count) metric\(measureTargets.count == 1 ? "" : "s"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Detailed view for forms and detail screens
    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overall progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overall Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(overallProgress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: overallProgress)
                    .tint(progressColor)
            }

            // Individual metric progress
            ForEach(measureTargets) { target in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(target.measureTitle ?? target.measureUnit)
                            .font(.subheadline)
                        Spacer()
                        progressText(for: target)
                    }

                    ProgressView(value: progressValue(for: target))
                        .tint(progressColor(for: target))
                }
            }
        }
    }

    /// Progress text for a specific metric
    private func progressText(for target: GoalData.MeasureTarget) -> some View {
        let actual = actualProgress[target.measureId] ?? 0
        let targetValue = target.targetValue
        let percentage = targetValue > 0 ? Int(min(actual / targetValue, 1.0) * 100) : 0

        return Text("\(actual, format: .number) / \(targetValue, format: .number) \(target.measureUnit) (\(percentage)%)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Calculate progress value for a specific metric (0.0 to 1.0)
    private func progressValue(for target: GoalData.MeasureTarget) -> Double {
        let actual = actualProgress[target.measureId] ?? 0
        let targetValue = target.targetValue
        guard targetValue > 0 else { return 0 }
        return min(actual / targetValue, 1.0)
    }

    /// Color based on overall progress
    private var progressColor: Color {
        switch overallProgress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .green
        default: return .blue  // 100% or more
        }
    }

    /// Color based on individual metric progress
    private func progressColor(for target: GoalData.MeasureTarget) -> Color {
        let progress = progressValue(for: target)
        switch progress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .green
        default: return .blue  // 100% or more
        }
    }
}

// MARK: - Previews

#Preview("Compact Mode") {
    let measureId1 = UUID()
    let measureId2 = UUID()

    return VStack(spacing: 20) {
        ProgressIndicator(
            measureTargets: [
                GoalData.MeasureTarget(
                    id: UUID(),
                    measureId: measureId1,
                    measureTitle: "Distance",
                    measureUnit: "km",
                    measureType: "distance",
                    targetValue: 120,
                    freeformNotes: nil,
                    createdAt: Date()
                ),
                GoalData.MeasureTarget(
                    id: UUID(),
                    measureId: measureId2,
                    measureTitle: "Sessions",
                    measureUnit: "sessions",
                    measureType: "count",
                    targetValue: 30,
                    freeformNotes: nil,
                    createdAt: Date()
                )
            ],
            actualProgress: [
                measureId1: 87,  // 72.5% of 120km
                measureId2: 18   // 60% of 30 sessions
            ],
            displayMode: .compact
        )

        ProgressIndicator(
            measureTargets: [],
            actualProgress: [:],
            displayMode: .compact
        )
    }
    .padding()
}

#Preview("Detailed Mode") {
    let measureId1 = UUID()
    let measureId2 = UUID()

    return ProgressIndicator(
        measureTargets: [
            GoalData.MeasureTarget(
                id: UUID(),
                measureId: measureId1,
                measureTitle: "Distance",
                measureUnit: "km",
                measureType: "distance",
                targetValue: 120,
                freeformNotes: nil,
                createdAt: Date()
            ),
            GoalData.MeasureTarget(
                id: UUID(),
                measureId: measureId2,
                measureTitle: "Sessions",
                measureUnit: "sessions",
                measureType: "count",
                targetValue: 30,
                freeformNotes: nil,
                createdAt: Date()
            )
        ],
        actualProgress: [
            measureId1: 87,  // 72.5% of 120km
            measureId2: 18   // 60% of 30 sessions
        ],
        displayMode: .detailed
    )
    .padding()
}
