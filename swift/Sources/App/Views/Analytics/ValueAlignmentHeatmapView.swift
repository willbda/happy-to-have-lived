//
// ValueAlignmentHeatmapView.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE:
// Heatmap visualization showing semantic alignment between goals and values.
// Uses Liquid Glass design language with rich backgrounds and regularMaterial.
//
// DESIGN PRINCIPLES (Liquid Glass):
// - Rich, vibrant background (contextual gradient)
// - .regularMaterial for heatmap grid (content layer)
// - Color-coded cells based on similarity score
// - Automatic glass navigation (no custom glass needed)
// - Tap interaction shows detail sheet
//
// ARCHITECTURE:
// ValueAlignmentHeatmapView → ValueAlignmentHeatmapViewModel
//                            → Repositories + ValueAlignmentService
//
// USAGE:
// ```swift
// NavigationLink("Value Alignment") {
//     ValueAlignmentHeatmapView()
// }
// ```

import SwiftUI
import Models

/// Value Alignment Heatmap view
///
/// **Visualization**: Grid showing goal-value semantic similarities
/// - Rows: Goals
/// - Columns: Values
/// - Cells: Color-coded by similarity strength
///
/// **Interaction**:
/// - Tap cell: Show detail sheet with alignment analysis
/// - Pull to refresh: Recompute matrix
@available(iOS 26.0, macOS 26.0, *)
public struct ValueAlignmentHeatmapView: View {

    // MARK: - State

    @State private var viewModel = ValueAlignmentHeatmapViewModel()
    @State private var selectedCell: AlignmentMatrix.Cell?

    // MARK: - Body

    public var body: some View {
        ZStack {
            // LAYER 1: Rich contextual background (Liquid Glass principle)
            backgroundView
                .ignoresSafeArea()

            // LAYER 2: Content with standard materials
            contentView
        }
        .navigationTitle("Value Alignment")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMatrix()
        }
        .refreshable {
            await viewModel.reloadMatrix()
        }
        .sheet(item: $selectedCell) { cell in
            AlignmentDetailSheet(
                cell: cell,
                goal: viewModel.goal(at: goalIndex(for: cell)),
                value: viewModel.value(at: valueIndex(for: cell))
            )
        }
    }

    // MARK: - Background View

    /// Rich contextual background following Liquid Glass design
    ///
    /// **Design Decision**: Subtle gradient that evokes analysis/insight
    /// - Not distracting (low contrast)
    /// - Complements heatmap colors
    /// - Works with .regularMaterial overlay
    @ViewBuilder
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.2),   // Deep blue
                Color(red: 0.15, green: 0.05, blue: 0.2),  // Purple tint
                Color(red: 0.05, green: 0.1, blue: 0.2)    // Back to blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let matrix = viewModel.alignmentMatrix {
                heatmapView(matrix: matrix)
            } else if viewModel.hasError {
                errorView
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Computing alignment matrix...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Analyzing semantic similarities")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Heatmap View

    @ViewBuilder
    private func heatmapView(matrix: AlignmentMatrix) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 24) {
                // Statistics header
                statisticsHeader(matrix: matrix)

                // Heatmap grid
                heatmapGrid(matrix: matrix)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
    }

    // MARK: - Statistics Header

    @ViewBuilder
    private func statisticsHeader(matrix: AlignmentMatrix) -> some View {
        let stats = matrix.statistics
        let totalCells = matrix.goals.count * matrix.values.count

        HStack(spacing: 20) {
            StatBadge(
                label: "Goals",
                value: "\(matrix.goals.count)",
                icon: "target"
            )

            StatBadge(
                label: "Values",
                value: "\(matrix.values.count)",
                icon: "heart.fill"
            )

            StatBadge(
                label: "Avg Alignment",
                value: String(format: "%.2f", stats.avgSimilarity),
                icon: "chart.bar.fill"
            )

            StatBadge(
                label: "Strong",
                value: String(format: "%.0f%%", stats.strongAlignmentPercentage(totalCells: totalCells)),
                icon: "flame.fill"
            )
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Heatmap Grid

    @ViewBuilder
    private func heatmapGrid(matrix: AlignmentMatrix) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 2, verticalSpacing: 2) {
            // Header row: Value titles
            GridRow {
                // Top-left corner spacer
                Color.clear
                    .frame(width: 140, height: 80)

                // Value column headers (rotated)
                ForEach(matrix.values.indices, id: \.self) { valueIndex in
                    Text(matrix.values[valueIndex].title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-45), anchor: .center)
                        .fixedSize()
                }
            }

            // Data rows: Goals × Values
            ForEach(matrix.goals.indices, id: \.self) { goalIndex in
                GridRow {
                    // Row header: Goal title
                    Text(matrix.goals[goalIndex].title ?? "Untitled Goal")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 140, alignment: .leading)
                        .lineLimit(2)
                        .padding(.trailing, 8)

                    // Cells: Similarity scores
                    ForEach(matrix.values.indices, id: \.self) { valueIndex in
                        let cell = matrix[goalIndex, valueIndex]

                        AlignmentCell(cell: cell)
                            .frame(width: 80, height: 60)
                            .onTapGesture {
                                selectedCell = cell
                            }
                    }
                }
            }
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Error Loading Alignment")
                .font(.headline)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                Task {
                    await viewModel.loadMatrix()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Data Available")
                .font(.headline)

            Text("Create goals and values to see alignment analysis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helper Methods

    /// Find goal index for cell (for detail sheet)
    private func goalIndex(for cell: AlignmentMatrix.Cell) -> Int {
        guard let matrix = viewModel.alignmentMatrix else { return 0 }
        return matrix.goals.firstIndex(where: { $0.id == cell.goalId }) ?? 0
    }

    /// Find value index for cell (for detail sheet)
    private func valueIndex(for cell: AlignmentMatrix.Cell) -> Int {
        guard let matrix = viewModel.alignmentMatrix else { return 0 }
        return matrix.values.firstIndex(where: { $0.id == cell.valueId }) ?? 0
    }

    // MARK: - Initializer

    public init() {}
}

// MARK: - Alignment Cell

/// Individual cell in heatmap grid
///
/// **Design**: Color-coded by similarity strength with score overlay
@available(iOS 26.0, macOS 26.0, *)
private struct AlignmentCell: View {
    let cell: AlignmentMatrix.Cell

    var body: some View {
        ZStack {
            // Background: Color-coded by alignment level
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    cell.alignmentLevel.color
                        .opacity(cell.alignmentLevel.opacity(for: cell.similarity))
                )

            // Foreground: Similarity score
            VStack(spacing: 4) {
                Text(String(format: "%.2f", cell.similarity))
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)

                // Alignment level badge
                Text(cell.alignmentLevel.rawValue)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Stat Badge

/// Statistics badge for header
@available(iOS 26.0, macOS 26.0, *)
private struct StatBadge: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Alignment Detail Sheet

/// Detail sheet shown when tapping a cell
///
/// **Design**: Shows goal, value, and alignment analysis
@available(iOS 26.0, macOS 26.0, *)
private struct AlignmentDetailSheet: View {
    let cell: AlignmentMatrix.Cell
    let goal: GoalData?
    let value: PersonalValueData?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Alignment strength header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    cell.alignmentLevel.color
                                        .opacity(cell.alignmentLevel.opacity(for: cell.similarity))
                                )
                                .frame(width: 120, height: 120)

                            VStack(spacing: 4) {
                                Text(String(format: "%.2f", cell.similarity))
                                    .font(.largeTitle.bold())

                                Text(cell.alignmentLevel.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Semantic Alignment")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)

                    // Goal details
                    if let goal = goal {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Goal", systemImage: "target")
                                .font(.headline)
                                .foregroundStyle(.blue)

                            Text(goal.title ?? "Untitled Goal")
                                .font(.title3.bold())

                            if let description = goal.detailedDescription {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Value details
                    if let value = value {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Value", systemImage: "heart.fill")
                                .font(.headline)
                                .foregroundStyle(.red)

                            Text(value.title)
                                .font(.title3.bold())

                            if let description = value.detailedDescription {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let guidance = value.alignmentGuidance {
                                Text("Guidance: \(guidance)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Interpretation guide
                    interpretationGuide

                }
                .padding()
            }
            .navigationTitle("Alignment Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Interpretation Guide

    @ViewBuilder
    private var interpretationGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Understanding Alignment")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                interpretationRow(level: .veryStrong, description: "Very Strong (0.90+): Near-identical semantic meaning")
                interpretationRow(level: .strong, description: "Strong (0.75-0.89): Clearly aligned concepts")
                interpretationRow(level: .moderate, description: "Moderate (0.60-0.74): Related concepts")
                interpretationRow(level: .weak, description: "Weak (<0.60): Minimal semantic overlap")
            }

            Text("Alignment scores are computed using semantic embeddings from your goal and value descriptions.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func interpretationRow(level: AlignmentMatrix.AlignmentLevel, description: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(level.color)
                .frame(width: 40, height: 20)

            Text(description)
                .font(.caption)
        }
    }
}

// MARK: - Identifiable Cell Extension

extension AlignmentMatrix.Cell: Identifiable {}

// MARK: - Preview

#Preview {
    NavigationStack {
        ValueAlignmentHeatmapView()
    }
}
