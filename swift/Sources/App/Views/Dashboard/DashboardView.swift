//
// DashboardView.swift
// Written by Claude Code on 2025-11-18
//
// PURPOSE:
// Main dashboard view showing analytics and insights.
// Features Value Alignment Heatmap as the primary analytics visualization.
//
// DESIGN PRINCIPLES (Liquid Glass):
// - Rich gradient background (analysis/insight theme)
// - .regularMaterial for content cards
// - Automatic glass navigation (system handles it)
// - Clear visual hierarchy
//
// ARCHITECTURE:
// DashboardView → Analytics cards with navigation links
//
// USAGE:
// ```swift
// TabView {
//     DashboardView()
//         .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
// }
// ```

import SwiftUI

/// Dashboard view with analytics and insights
///
/// **Features**:
/// - Value Alignment Heatmap (primary analytics)
/// - Goal progress summary (future)
/// - Action trends (future)
/// - Values reflection (future)
@available(iOS 26.0, macOS 26.0, *)
public struct DashboardView: View {

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                // LAYER 1: Rich contextual background
                backgroundView
                    .ignoresSafeArea()

                // LAYER 2: Content with standard materials
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Welcome header
                        welcomeHeader
                            .padding(.horizontal)
                            .padding(.top)

                        // Analytics cards
                        analyticsCards
                            .padding(.horizontal)

                        // Footer
                        footerText
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Background View

    /// Rich gradient background following Liquid Glass design
    ///
    /// **Design Decision**: Analysis/insight theme
    /// - Deep blue → purple gradient
    /// - Low contrast (doesn't compete with content)
    /// - Works with .regularMaterial overlay
    @ViewBuilder
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.2),   // Deep blue
                Color(red: 0.1, green: 0.05, blue: 0.15),  // Purple
                Color(red: 0.05, green: 0.1, blue: 0.2)    // Back to blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Welcome Header

    @ViewBuilder
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analytics & Insights")
                .font(.title2.bold())

            Text("Understand how your goals align with your values")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Analytics Cards

    @ViewBuilder
    private var analyticsCards: some View {
        VStack(spacing: 16) {
            // Primary: Value Alignment Heatmap
            NavigationLink {
                ValueAlignmentHeatmapView()
            } label: {
                AnalyticsCard(
                    icon: "chart.bar.xaxis",
                    title: "Value Alignment Heatmap",
                    subtitle: "See which goals align with your values",
                    color: .red,
                    isLarge: true
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Future analytics (placeholders)
            HStack(spacing: 16) {
                PlaceholderCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress Trends",
                    subtitle: "Coming soon"
                )

                PlaceholderCard(
                    icon: "flame.fill",
                    title: "Action Streaks",
                    subtitle: "Coming soon"
                )
            }

            PlaceholderCard(
                icon: "heart.text.square.fill",
                title: "Values Reflection",
                subtitle: "Weekly reflection coming soon"
            )
        }
    }

    // MARK: - Footer Text

    @ViewBuilder
    private var footerText: some View {
        Text("More analytics and insights coming soon")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Initializer

    public init() {}
}

// MARK: - Analytics Card

/// Large analytics card with icon, title, and subtitle
@available(iOS 26.0, macOS 26.0, *)
private struct AnalyticsCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isLarge: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Placeholder Card

/// Placeholder card for future analytics
@available(iOS 26.0, macOS 26.0, *)
private struct PlaceholderCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.gray)

            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(0.6)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}
