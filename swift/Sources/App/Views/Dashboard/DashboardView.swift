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
