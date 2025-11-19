//
  // ContentView.swift
  // Root view for TenWeekGoalApp
  //
  // Updated by Claude Code on 2025-11-18

  import SwiftUI

  /// Root view for the application
  ///
  /// Provides tab-based navigation with Dashboard as the landing page.
  /// Updated 2025-11-18: Dashboard now includes Value Alignment Heatmap analytics.
  public struct ContentView: View {

      public init() {}

      public var body: some View {
          TabView {
              // Tab 1: Dashboard (Analytics & Insights)
              if #available(iOS 26.0, macOS 26.0, *) {
                  DashboardView()
                      .tabItem {
                          Label("Dashboard", systemImage: "chart.bar.fill")
                      }
              } else {
                  PlaceholderTab(
                      icon: "chart.bar.fill",
                      title: "Dashboard",
                      subtitle: "Requires iOS 26+ for analytics features"
                  )
                  .tabItem {
                      Label("Dashboard", systemImage: "chart.bar.fill")
                  }
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

              // Tab 5: Milestones (Phase 2 - Complete)
              NavigationStack {
                  MilestonesListView()
              }
              .tabItem {
                  Label("Milestones", systemImage: "flag")
              }

              // Tab 6: Obligations (Phase 2 - Complete)
              NavigationStack {
                  ObligationsListView()
              }
              .tabItem {
                  Label("Obligations", systemImage: "checkmark.circle")
              }

              // Tab 7: Values (Phase 3 - Complete)
              NavigationStack {
                  PersonalValuesListView()
              }
              .tabItem {
                  Label("Values", systemImage: "heart.fill")
              }

              // Tab 8: Import (CSV Import/Export)
              NavigationStack {
                  CSVExportImportView()
              }
              .tabItem {
                  Label("Import", systemImage: "arrow.2.circlepath.circle")
              }

              // Tab 9: Health (iOS only - HealthKit workouts)
              #if os(iOS)
              NavigationStack {
                  WorkoutsTestView()
              }
              .tabItem {
                  Label("Health", systemImage: "heart.text.square")
              }
              #endif

              // Tab 10: Debug Tools
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

