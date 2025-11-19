//
  // ContentView.swift
  // Root view for TenWeekGoalApp
  //
  // Updated by Claude Code on 2025-11-18
  // Simplified to follow HIG guidance (5-tab maximum)

  import SwiftUI

  /// Root view for the application
  ///
  /// Follows Apple HIG guidance for tab-based navigation:
  /// - 5 primary tabs maximum (iOS compact class limit)
  /// - Modern iOS 26+ Tab() API
  /// - Platform-adaptive styling (sidebar on iPadOS)
  /// - Dashboard-first orientation ("What's Happening Now")
  public struct ContentView: View {

      public init() {}

      public var body: some View {
          TabView {
              // Tab 1: Dashboard (What's Happening Now)
              Tab("Dashboard", systemImage: "chart.bar.fill") {
                  DashboardView()
              }

              // Tab 2: Actions (Activity Log)
              Tab("Actions", systemImage: "checkmark.circle") {
                  ActionsListView()
              }

              // Tab 3: Goals (Planning)
              Tab("Goals", systemImage: "target") {
                  GoalsListView()
              }

              // Tab 4: Values (Principles)
              Tab("Values", systemImage: "heart.fill") {
                  PersonalValuesListView()
              }

              // Tab 5: Terms (Planning Periods)
              Tab("Terms", systemImage: "calendar") {
                  TermsListView()
              }
          }
          .tabViewStyle(.sidebarAdaptable)
      }
  }

  // MARK: - Placeholder Views

  /// Generic placeholder for future tabs
  private struct PlaceholderTab: View {
      let icon: String
      let title: String
      let subtitle: String

      var body: some View {
          NavigationStack {
              VStack(spacing: 20) {
                  Image(systemName: icon)
                      .font(.system(size: 60))
                      .foregroundStyle(.gray)

                  Text(title)
                      .font(.largeTitle)
                      .fontWeight(.bold)

                  Text(subtitle)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
              }
              .navigationTitle(title)
          }
      }
  }

  #Preview {
      ContentView()
  }

