//
// GoalProgressGauge.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Modern progress visualization using iOS 16+ Gauge component
// REPLACES: ProgressIndicator.swift (245 lines → ~145 lines)
//
// BENEFITS:
// - Automatic platform adaptation (iOS/macOS/visionOS)
// - System-provided animations and Liquid Glass effects
// - Semantic colors handled by system
// - Accessibility built-in (VoiceOver, Dynamic Type, Reduce Motion)
//

import Models
import SwiftUI

/// Modern progress visualization using system Gauge component
///
/// **Benefits over custom implementation**:
/// - Automatic platform adaptation (iOS/macOS/visionOS)
/// - System-provided animations
/// - Semantic colors handled by system
/// - Accessibility built-in (VoiceOver, Dynamic Type)
/// - Respects Reduce Motion setting
@available(iOS 16.0, macOS 13.0, *)
public struct GoalProgressGauge: View {
    let measureTargets: [GoalData.MeasureTarget]
    let actualProgress: [UUID: Double]
    let displayMode: DisplayMode

    public enum DisplayMode {
        case compact   // Single circular gauge
        case detailed  // Multiple linear gauges
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

    // MARK: - Computed Progress

    private var overallProgress: Double {
        guard !measureTargets.isEmpty else { return 0 }

        let progresses = measureTargets.compactMap { target -> Double? in
            guard let actual = actualProgress[target.measureId],
                  target.targetValue > 0 else { return nil }
            return min(actual / target.targetValue, 1.0)
        }

        guard !progresses.isEmpty else { return 0 }
        return progresses.reduce(0, +) / Double(progresses.count)
    }

    // MARK: - Body

    public var body: some View {
        switch displayMode {
        case .compact:
            compactGauge
        case .detailed:
            detailedGauges
        }
    }

    // MARK: - Compact View

    private var compactGauge: some View {
        HStack(spacing: 8) {
            // System Gauge - automatic animations and accessibility
            Gauge(value: overallProgress, in: 0...1) {
                Text("Progress")
            } currentValueLabel: {
                Text("\(Int(overallProgress * 100))%")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(progressColor)  // System handles semantic meaning
            .frame(width: 32, height: 32)

            if !measureTargets.isEmpty {
                Text("(\(measureTargets.count) metric\(measureTargets.count == 1 ? "" : "s"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Detailed View

    private var detailedGauges: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(overallProgress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Gauge(value: overallProgress, in: 0...1) {
                    Text("Overall")
                }
                .gaugeStyle(.linearCapacity)
                .tint(progressColor)
            }

            // Individual metrics
            ForEach(measureTargets) { target in
                individualMetricGauge(for: target)
            }
        }
    }

    @ViewBuilder
    private func individualMetricGauge(for target: GoalData.MeasureTarget) -> some View {
        let progress = progressValue(for: target)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(target.measureTitle ?? target.measureUnit)
                    .font(.subheadline)
                Spacer()
                progressLabel(for: target)
            }

            Gauge(value: progress, in: 0...1) {
                Text(target.measureTitle ?? target.measureUnit)
            }
            .gaugeStyle(.linearCapacity)
            .tint(semanticColor(for: progress))
        }
    }

    @ViewBuilder
    private func progressLabel(for target: GoalData.MeasureTarget) -> some View {
        let actual = actualProgress[target.measureId] ?? 0
        let percentage = Int(progressValue(for: target) * 100)

        Text("\(actual, format: .number) / \(target.targetValue, format: .number) \(target.measureUnit) (\(percentage)%)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func progressValue(for target: GoalData.MeasureTarget) -> Double {
        let actual = actualProgress[target.measureId] ?? 0
        guard target.targetValue > 0 else { return 0 }
        return min(actual / target.targetValue, 1.0)
    }

    // System semantic colors - automatically adapt to accessibility settings
    private var progressColor: Color {
        semanticColor(for: overallProgress)
    }

    private func semanticColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .green
        default: return .blue
        }
    }
}

// MARK: - Previews

#Preview("Compact") {
    let measureId1 = UUID()
    let measureId2 = UUID()

    return VStack(spacing: 20) {
        GoalProgressGauge(
            measureTargets: [
                GoalData.MeasureTarget(
                    id: UUID(), measureId: measureId1,
                    measureTitle: "Distance", measureUnit: "km",
                    measureType: "distance", targetValue: 120,
                    freeformNotes: nil, createdAt: Date()
                ),
                GoalData.MeasureTarget(
                    id: UUID(), measureId: measureId2,
                    measureTitle: "Sessions", measureUnit: "sessions",
                    measureType: "count", targetValue: 30,
                    freeformNotes: nil, createdAt: Date()
                )
            ],
            actualProgress: [measureId1: 87, measureId2: 18],
            displayMode: .compact
        )

        GoalProgressGauge(
            measureTargets: [],
            actualProgress: [:],
            displayMode: .compact
        )
    }
    .padding()
}

#Preview("Detailed") {
    let measureId1 = UUID()
    let measureId2 = UUID()

    return GoalProgressGauge(
        measureTargets: [
            GoalData.MeasureTarget(
                id: UUID(), measureId: measureId1,
                measureTitle: "Distance", measureUnit: "km",
                measureType: "distance", targetValue: 120,
                freeformNotes: nil, createdAt: Date()
            ),
            GoalData.MeasureTarget(
                id: UUID(), measureId: measureId2,
                measureTitle: "Sessions", measureUnit: "sessions",
                measureType: "count", targetValue: 30,
                freeformNotes: nil, createdAt: Date()
            )
        ],
        actualProgress: [measureId1: 87, measureId2: 18],
        displayMode: .detailed
    )
    .padding()
}
