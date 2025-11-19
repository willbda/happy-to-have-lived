//
// ValueAlignmentInsightsView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: Redesigned value alignment view using HIG-compliant patterns
// REPLACES: ValueAlignmentHeatmapView (overly busy, poor UX)
//
// DESIGN PRINCIPLES:
// - Progressive disclosure (overview → details → specifics)
// - Semantic color system (not arbitrary heatmap colors)
// - Liquid Glass visual hierarchy
// - Actionable insights (not raw similarity scores)
//
// ARCHITECTURE:
// ValueAlignmentInsightsView → ValueAlignmentHeatmapViewModel
//                            → AlignmentInsights (computed insights)
//                            → AlignmentMatrix (raw similarity data)

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct ValueAlignmentInsightsView: View {
    @State private var viewModel = ValueAlignmentHeatmapViewModel()
    @State private var selectedSection: InsightSection?

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Analyzing alignment...")
            } else if let matrix = viewModel.alignmentMatrix {
                insightsContent(matrix: matrix)
            } else if viewModel.hasError {
                ContentUnavailableView {
                    Label("Analysis Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(viewModel.errorMessage ?? "Unknown error")
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.loadMatrix() }
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
        .sheet(item: $selectedSection) { section in
            NavigationStack {
                sectionDetailView(for: section, matrix: viewModel.alignmentMatrix!)
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func insightsContent(matrix: AlignmentMatrix) -> some View {
        let insights = AlignmentInsights(matrix: matrix)

        List {
            // Portfolio Health Overview
            portfolioHealthSection(insights: insights)

            // Key Insights (Top 3)
            keyInsightsSection(insights: insights)

            // Detailed Sections (Progressive Disclosure)
            detailedInsightsSection(insights: insights)
        }

    }

    // MARK: - Portfolio Health Section

    @ViewBuilder
    private func portfolioHealthSection(insights: AlignmentInsights) -> some View {
        Section {
            VStack(spacing: 16) {
                // Overall Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: insights.portfolioHealth.overallScore)
                        .stroke(
                            healthGradient(for: insights.portfolioHealth.healthLevel),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(Int(insights.portfolioHealth.overallScore * 100))")
                            .font(.system(size: 36, weight: .bold))
                        Text(insights.portfolioHealth.healthLevel.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Key Metrics
                HStack(spacing: 24) {
                    metricColumn(
                        value: "\(Int(insights.portfolioHealth.valueCoveragePercentage))%",
                        label: "Values Covered"
                    )
                    metricColumn(
                        value: "\(insights.portfolioHealth.goalDistribution.total)",
                        label: "Goals Analyzed"
                    )
                    metricColumn(
                        value: String(format: "%.2f", insights.portfolioHealth.averageAlignment),
                        label: "Avg Alignment"
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("Portfolio Health")
        }
    }

    // MARK: - Key Insights Section

    @ViewBuilder
    private func keyInsightsSection(insights: AlignmentInsights) -> some View {
        Section {
            // Top underserved value (if any)
            if let topUnderserved = insights.underservedValues.first {
                InsightRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    title: "Underserved Value",
                    subtitle: "\"\(topUnderserved.value.title)\" needs goal support",
                    action: {
                        selectedSection = .underservedValues
                    }
                )
            }

            // Disconnected goals (if any)
            if !insights.disconnectedGoals.isEmpty {
                InsightRow(
                    icon: "link.badge.xmark",
                    iconColor: .red,
                    title: "\(insights.disconnectedGoals.count) Disconnected Goal\(insights.disconnectedGoals.count == 1 ? "" : "s")",
                    subtitle: "Goals with weak value alignment",
                    action: {
                        selectedSection = .disconnectedGoals
                    }
                )
            }

            // Holistic goals (if any)
            if !insights.holisticGoals.isEmpty {
                InsightRow(
                    icon: "sparkles",
                    iconColor: .green,
                    title: "\(insights.holisticGoals.count) Holistic Goal\(insights.holisticGoals.count == 1 ? "" : "s")",
                    subtitle: "Goals serving multiple values",
                    action: {
                        selectedSection = .holisticGoals
                    }
                )
            }
        } header: {
            Text("Key Insights")
        }
    }

    // MARK: - Detailed Insights Section

    @ViewBuilder
    private func detailedInsightsSection(insights: AlignmentInsights) -> some View {
        Section {
            NavigationLink {
                ValueCoverageDetailView(insights: insights)
            } label: {
                HStack {
                    Label("Value Coverage", systemImage: "heart.text.square")
                    Spacer()
                    Text("\(insights.wellServedValues.count)/\(insights.matrix.values.count)")
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                GoalFocusDetailView(insights: insights)
            } label: {
                HStack {
                    Label("Goal Focus", systemImage: "target")
                    Spacer()
                    Text("\(insights.portfolioHealth.goalDistribution.holistic)H · \(insights.portfolioHealth.goalDistribution.focused)F")
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                AlignmentMatrixDetailView(matrix: insights.matrix)
            } label: {
                Label("Full Matrix View", systemImage: "square.grid.3x3")
            }
        } header: {
            Text("Detailed Analysis")
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func metricColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func healthGradient(for level: AlignmentInsights.HealthLevel) -> LinearGradient {
        switch level {
        case .poor:
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        case .fair:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .good:
            return LinearGradient(colors: [.yellow, .green], startPoint: .leading, endPoint: .trailing)
        case .excellent:
            return LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
        }
    }

    @ViewBuilder
    private func sectionDetailView(for section: InsightSection, matrix: AlignmentMatrix) -> some View {
        let insights = AlignmentInsights(matrix: matrix)

        switch section {
        case .underservedValues:
            UnderservedValuesDetailView(insights: insights)
        case .disconnectedGoals:
            DisconnectedGoalsDetailView(insights: insights)
        case .holisticGoals:
            HolisticGoalsDetailView(insights: insights)
        }
    }
}

// MARK: - Insight Row Component

@available(iOS 26.0, macOS 26.0, *)
private struct InsightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Views

@available(iOS 26.0, macOS 26.0, *)
private struct ValueCoverageDetailView: View {
    let insights: AlignmentInsights
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !insights.underservedValues.isEmpty {
                Section {
                    ForEach(insights.underservedValues) { coverage in
                        ValueCoverageRow(coverage: coverage)
                    }
                } header: {
                    Text("Underserved Values")
                } footer: {
                    Text("These values have weak alignment with your current goals. Consider creating goals that directly support them.")
                }
            }

            if !insights.wellServedValues.isEmpty {
                Section {
                    ForEach(insights.wellServedValues) { coverage in
                        ValueCoverageRow(coverage: coverage)
                    }
                } header: {
                    Text("Well-Served Values")
                } footer: {
                    Text("These values are well-represented in your goal portfolio.")
                }
            }
        }
        .navigationTitle("Value Coverage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct ValueCoverageRow: View {
    let coverage: AlignmentInsights.ValueCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(coverage.value.title)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%%", coverage.averageAlignment * 100))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(colorFor(coverage.severity))
            }

            // Alignment bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFor(coverage.severity))
                        .frame(width: geometry.size.width * coverage.averageAlignment, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(coverage.strongGoalCount) strong alignment\(coverage.strongGoalCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(coverage.recommendation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func colorFor(_ severity: AlignmentInsights.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .moderate: return .yellow
        case .low: return .green
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct GoalFocusDetailView: View {
    let insights: AlignmentInsights
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !insights.holisticGoals.isEmpty {
                Section {
                    ForEach(insights.holisticGoals) { focus in
                        GoalFocusRow(focus: focus)
                    }
                } header: {
                    Text("Holistic Goals (\(insights.holisticGoals.count))")
                } footer: {
                    Text("These goals serve 3+ values. Progress here has high leverage across your life.")
                }
            }

            if !insights.focusedGoals.isEmpty {
                Section {
                    ForEach(insights.focusedGoals) { focus in
                        GoalFocusRow(focus: focus)
                    }
                } header: {
                    Text("Focused Goals (\(insights.focusedGoals.count))")
                } footer: {
                    Text("These goals serve 1-2 values. Clear purpose makes progress easier to measure.")
                }
            }

            if !insights.disconnectedGoals.isEmpty {
                Section {
                    ForEach(insights.disconnectedGoals) { focus in
                        GoalFocusRow(focus: focus)
                    }
                } header: {
                    Text("Disconnected Goals (\(insights.disconnectedGoals.count))")
                } footer: {
                    Text("These goals have weak alignment with your stated values. Consider reviewing their purpose.")
                }
            }
        }
        .navigationTitle("Goal Focus")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct GoalFocusRow: View {
    let focus: AlignmentInsights.GoalFocus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(focus.goal.title ?? "Untitled")
                    .font(.headline)
                Spacer()
                Text(focus.focusType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorFor(focus.focusType).opacity(0.2))
                    .foregroundStyle(colorFor(focus.focusType))
                    .clipShape(Capsule())
            }

            if !focus.alignedValues.isEmpty {
                Text("Serves: \(focus.alignedValues.map { $0.title }.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let primary = focus.primaryValue {
                Text("Closest to: \(primary.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorFor(_ type: AlignmentInsights.GoalFocus.FocusType) -> Color {
        switch type {
        case .holistic: return .green
        case .focused: return .blue
        case .disconnected: return .red
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct UnderservedValuesDetailView: View {
    let insights: AlignmentInsights
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ValueCoverageDetailView(insights: insights)
            .navigationTitle("Underserved Values")
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct DisconnectedGoalsDetailView: View {
    let insights: AlignmentInsights
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(insights.disconnectedGoals) { focus in
                GoalFocusRow(focus: focus)
            }
        }
        .navigationTitle("Disconnected Goals")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct HolisticGoalsDetailView: View {
    let insights: AlignmentInsights
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(insights.holisticGoals) { focus in
                GoalFocusRow(focus: focus)
            }
        }
        .navigationTitle("Holistic Goals")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct AlignmentMatrixDetailView: View {
    let matrix: AlignmentMatrix
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 4) {
                    Text("")
                        .frame(width: 100)
                    ForEach(matrix.values) { value in
                        Text(value.title)
                            .font(.caption2)
                            .frame(width: 60)
                            .lineLimit(1)
                            .rotationEffect(.degrees(-45))
                            .fixedSize()
                    }
                }
                .padding(.bottom, 40)

                // Data rows
                ForEach(matrix.goals.indices, id: \.self) { goalIndex in
                    HStack(spacing: 4) {
                        Text(matrix.goals[goalIndex].title ?? "")
                            .font(.caption2)
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(2)

                        ForEach(matrix.values.indices, id: \.self) { valueIndex in
                            let cell = matrix[goalIndex, valueIndex]
                            Rectangle()
                                .fill(colorFor(cell.similarity).opacity(0.3 + cell.similarity * 0.7))
                                .frame(width: 60, height: 30)
                                .overlay {
                                    Text(String(format: "%.0f", cell.similarity * 100))
                                        .font(.caption2.monospacedDigit())
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Alignment Matrix")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func colorFor(_ similarity: Double) -> Color {
        switch similarity {
        case 0.0..<0.30: return .gray
        case 0.30..<0.60: return .yellow
        case 0.60..<0.75: return .orange
        default: return .green
        }
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, *)
private enum InsightSection: Identifiable {
    case underservedValues
    case disconnectedGoals
    case holisticGoals

    var id: String {
        switch self {
        case .underservedValues: return "underserved"
        case .disconnectedGoals: return "disconnected"
        case .holisticGoals: return "holistic"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ValueAlignmentInsightsView()
    }
}
