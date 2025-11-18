//
  // ContentView.swift
  // Root view for TenWeekGoalApp
  //
  // Updated by Claude Code on 2025-11-01

  import SwiftUI

  /// Root view for the application
  ///
  /// Provides tab-based navigation with Dashboard as the landing page.
  /// Updated 2025-11-10: Dashboard added as first tab for goal progress overview.
  public struct ContentView: View {

      public init() {}

      public var body: some View {
          TabView {
              // Tab 1: Dashboard (Coming Soon - Removed during v0.7 cleanup)
              PlaceholderTab(
                  icon: "chart.bar.fill",
                  title: "Dashboard",
                  subtitle: "Goal progress analytics coming soon"
              )
              .tabItem {
                  Label("Dashboard", systemImage: "chart.bar.fill")
              }

              // Tab 2: Actions (Phase 1 Complete - Full CRUD)
              NavigationStack {
                  ActionsListView()
              }
              .tabItem {
                  Label("Actions", systemImage: "checkmark.circle")
              }

              // Tab 3: Terms (Phase 1 - Complete)
              NavigationStack {
                  TermsListView()
              }
              .tabItem {
                  Label("Terms", systemImage: "calendar")
              }

              // Tab 4: Goals (Phase 2)
              NavigationStack {
                  GoalsListView()
              }.tabItem{
                  Label("Goals", systemImage: "target")

              }

              // Tab 5: Values (Phase 3 - Complete)
              NavigationStack {
                  PersonalValuesListView()
              }
              .tabItem {
                  Label("Values", systemImage: "heart.fill")
              }

              // Tab 6: Import (CSV Import/Export)
              NavigationStack {
                  CSVExportImportView()
              }
              .tabItem {
                  Label("Import", systemImage: "arrow.2.circlepath.circle")
              }

              // Tab 7: Health (iOS only - HealthKit workouts)
              #if os(iOS)
              NavigationStack {
                  WorkoutsTestView()
              }
              .tabItem {
                  Label("Health", systemImage: "heart.text.square")
              }
              #endif

              // Tab 8: Debug Tools
              NavigationStack {
                  List {
                      Section("Data Cleanup") {
                          NavigationLink {
                              MeasureDeduplicationView()
                          } label: {
                              Label("Deduplicate Measures", systemImage: "arrow.triangle.merge")
                          }
                      }

                      Section("Sync") {
                          NavigationLink {
                              SyncDebugView()
                          } label: {
                              Label("CloudKit Sync Status", systemImage: "icloud.and.arrow.up.fill")
                          }
                      }
                  }
                  .navigationTitle("Debug Tools")
              }
              .tabItem {
                  Label("Debug", systemImage: "wrench.and.screwdriver")
              }
          }
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

