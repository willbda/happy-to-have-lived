//
// DashboardView.swift
// Written by Claude Code on 2025-11-18
// Updated by Claude Code on 2025-11-19
//
// PURPOSE: Main dashboard with analytics cards
// ARCHITECTURE: Progressive disclosure - summary cards → detail views
//

import SwiftUI
import Models

@available(iOS 26.0, macOS 26.0, *)
public struct DashboardView: View {

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    welcomeSection

                    // Value Alignment Summary Card (primary insight)
                    NavigationLink {
                        ValueAlignmentInsightsView()
                    } label: {
                        ValueAlignmentSummaryCard()
                    }
                    .buttonStyle(.plain)

                    // Quick Links Section
                    quickLinksSection
                }
                .padding()
            }
            .background(.regularMaterial)  // System material with automatic Liquid Glass
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }

    // MARK: - Welcome Section

    @ViewBuilder
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome")
                .font(.title2.bold())

            Text("Your goal portfolio overview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quick Links Section

    @ViewBuilder
    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickLinkCard(
                    icon: "target",
                    title: "Goals",
                    color: .blue,
                    destination: AnyView(GoalsListView())
                )

                QuickLinkCard(
                    icon: "checkmark.circle",
                    title: "Actions",
                    color: .green,
                    destination: AnyView(ActionsListView())
                )

                QuickLinkCard(
                    icon: "heart.fill",
                    title: "Values",
                    color: .red,
                    destination: AnyView(PersonalValuesListView())
                )

                QuickLinkCard(
                    icon: "calendar",
                    title: "Terms",
                    color: .orange,
                    destination: AnyView(TermsListView())
                )
            }
        }
    }
}

// MARK: - Value Alignment Summary Card

@available(iOS 26.0, macOS 26.0, *)
private struct ValueAlignmentSummaryCard: View {
    @State private var viewModel = ValueAlignmentHeatmapViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Value Alignment", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Content
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.hasError {
                errorContent
            } else if let matrix = viewModel.alignmentMatrix {
                summaryContent(matrix: matrix)
            } else {
                emptyContent
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            await viewModel.loadMatrix()
        }
    }

    @ViewBuilder
    private func summaryContent(matrix: AlignmentMatrix) -> some View {
        let insights = AlignmentInsights(matrix: matrix)

        HStack(spacing: 24) {
            // Portfolio Health Score
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: insights.portfolioHealth.overallScore)
                        .stroke(
                            healthGradient(for: insights.portfolioHealth.healthLevel),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(insights.portfolioHealth.overallScore * 100))")
                        .font(.title.bold())
                }

                Text(insights.portfolioHealth.healthLevel.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Key Metrics
            VStack(alignment: .leading, spacing: 8) {
                metricRow(
                    label: "Values Covered",
                    value: "\(Int(insights.portfolioHealth.valueCoveragePercentage))%"
                )

                metricRow(
                    label: "Goals Analyzed",
                    value: "\(insights.portfolioHealth.goalDistribution.total)"
                )

                if !insights.underservedValues.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("\(insights.underservedValues.count) underserved value\(insights.underservedValues.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Unable to load alignment data")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private var emptyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Add goals and values to see alignment")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
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
}

// MARK: - Quick Link Card

@available(iOS 26.0, macOS 26.0, *)
private struct QuickLinkCard: View {
    let icon: String
    let title: String
    let color: Color
    let destination: AnyView

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView()
}
