//
// ValueAlignmentHeatmapView.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE: Heatmap visualization showing semantic alignment between goals and values
// DATA SOURCE: ValueAlignmentHeatmapViewModel
// INTERACTIONS: Tap cell to see details
//

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct ValueAlignmentHeatmapView: View {
    @State private var viewModel = ValueAlignmentHeatmapViewModel()
    @State private var selectedCell: AlignmentMatrix.Cell?

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Computing alignments...")
            } else if let matrix = viewModel.alignmentMatrix {
                List {
                    Section("Statistics") {
                        statisticsRow(matrix: matrix)
                    }

                    Section {
                        ScrollView(.horizontal) {
                            heatmapGrid(matrix: matrix)
                        }
                    } header: {
                        Text("Alignment Matrix")
                    } footer: {
                        Text("Tap any cell to see details")
                    }
                }
            } else if viewModel.hasError {
                ContentUnavailableView {
                    Label("Error Loading Data", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(viewModel.errorMessage ?? "Unknown error")
                } actions: {
                    Button("Try Again") {
                        Task {
                            await viewModel.loadMatrix()
                        }
                    }
                }
            }
        }
        .navigationTitle("Value Alignment")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await viewModel.loadMatrix()
        }
        .refreshable {
            await viewModel.reloadMatrix()
        }
        .sheet(item: $selectedCell) { cell in
            NavigationStack {
                AlignmentDetailSheet(
                    cell: cell,
                    goal: viewModel.goal(at: goalIndex(for: cell)),
                    value: viewModel.value(at: valueIndex(for: cell))
                )
            }
        }
    }

    @ViewBuilder
    private func statisticsRow(matrix: AlignmentMatrix) -> some View {
        let stats = matrix.statistics
        let totalCells = matrix.goals.count * matrix.values.count

        HStack {
            VStack(alignment: .leading) {
                Text("\(matrix.goals.count) goals × \(matrix.values.count) values")
                    .font(.headline)
                Text("Avg: \(String(format: "%.2f", stats.avgSimilarity)) • Strong: \(Int(stats.strongAlignmentPercentage(totalCells: totalCells)))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func heatmapGrid(matrix: AlignmentMatrix) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("").frame(width: 120)
                ForEach(matrix.values.indices, id: \.self) { i in
                    Text(matrix.values[i].title)
                        .font(.caption)
                        .frame(width: 80)
                        .lineLimit(2)
                }
            }

            Divider()

            // Rows
            ForEach(matrix.goals.indices, id: \.self) { goalIndex in
                HStack(spacing: 8) {
                    Text(matrix.goals[goalIndex].title ?? "Untitled")
                        .font(.caption)
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(2)

                    ForEach(matrix.values.indices, id: \.self) { valueIndex in
                        let cell = matrix[goalIndex, valueIndex]
                        Button {
                            selectedCell = cell
                        } label: {
                            VStack(spacing: 2) {
                                Text(String(format: "%.2f", cell.similarity))
                                    .font(.caption2.monospacedDigit())
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorFor(cell.alignmentLevel))
                                    .frame(width: 80, height: 20)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if goalIndex < matrix.goals.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
    }

    private func colorFor(_ level: AlignmentMatrix.AlignmentLevel) -> Color {
        switch level {
        case .weak: return .gray
        case .moderate: return .yellow
        case .strong: return .orange
        case .veryStrong: return .red
        }
    }

    private func goalIndex(for cell: AlignmentMatrix.Cell) -> Int {
        viewModel.alignmentMatrix?.goals.firstIndex(where: { $0.id == cell.goalId }) ?? 0
    }

    private func valueIndex(for cell: AlignmentMatrix.Cell) -> Int {
        viewModel.alignmentMatrix?.values.firstIndex(where: { $0.id == cell.valueId }) ?? 0
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct AlignmentDetailSheet: View {
    let cell: AlignmentMatrix.Cell
    let goal: GoalData?
    let value: PersonalValueData?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack {
                    Circle()
                        .fill(colorFor(cell.alignmentLevel).gradient)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(String(format: "%.2f", cell.similarity))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    Text(cell.alignmentLevel.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if let goal = goal {
                Section("Goal") {
                    Text(goal.title ?? "Untitled")
                        .font(.headline)
                    if let description = goal.detailedDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let value = value {
                Section("Value") {
                    Text(value.title)
                        .font(.headline)
                    if let description = value.detailedDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Understanding Alignment") {
                ForEach(AlignmentMatrix.AlignmentLevel.allCases, id: \.self) { level in
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(level))
                            .frame(width: 30, height: 15)
                        Text(level.rawValue)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Alignment Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func colorFor(_ level: AlignmentMatrix.AlignmentLevel) -> Color {
        switch level {
        case .weak: return .gray
        case .moderate: return .yellow
        case .strong: return .orange
        case .veryStrong: return .red
        }
    }
}

extension AlignmentMatrix.Cell: Identifiable {}

#Preview {
    NavigationStack {
        ValueAlignmentHeatmapView()
    }
}
