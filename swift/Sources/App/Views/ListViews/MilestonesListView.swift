//
// MilestonesListView.swift
// Written by Claude Code on 2025-11-19
// Refactored by Claude Code on 2025-11-20 - Uses DataStore (declarative pattern)
//
// PURPOSE: List of milestones with upcoming dates
// DATA SOURCE: DataStore (ValueObservation for automatic updates)
// INTERACTIONS: Tap to view, swipe to delete, empty state
//

import Models
import Services
import SwiftUI

/// List view for milestones
///
/// **PATTERN**: DataStore-based (declarative pattern, consistent with Goals/Actions/Values/Terms)
/// **DATA**: DataStore → ValueObservation → Automatic UI updates
/// **DISPLAY**: MilestoneRowView for each milestone
/// **INTERACTIONS**: Swipe to delete, pull to refresh
///
public struct MilestonesListView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var showingAddMilestone = false
    @State private var milestoneToDelete: MilestoneWithDetails?
    @State private var showingDeleteAlert = false

    public init() {}

    public var body: some View {
        Group {
            if dataStore.isLoading {
                // Loading state
                ProgressView("Loading milestones...")
            } else if dataStore.milestones.isEmpty {
                // Empty state
                ContentUnavailableView {
                    Label("No Milestones Yet", systemImage: "flag")
                } description: {
                    Text("Add your first milestone to track important checkpoints")
                } actions: {
                    Button("Add Milestone") {
                        showingAddMilestone = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Milestone list
                List {
                    ForEach(dataStore.milestones) { milestoneData in
                        MilestoneRowView(milestone: milestoneData)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    milestoneToDelete = milestoneData
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Milestones")
        .errorAlert(dataStore: dataStore)  // ✅ Unified error handling
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddMilestone = true
                } label: {
                    Label("Add Milestone", systemImage: "plus")
                }
            }
        }
        .refreshable {
            // Manual refresh (ValueObservation handles automatic updates)
            await dataStore.loadMilestones()
        }
        .sheet(isPresented: $showingAddMilestone) {
            NavigationStack {
                MilestoneFormView()
            }
        }
        .alert("Delete Milestone?", isPresented: $showingDeleteAlert, presenting: milestoneToDelete) { milestoneData in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await dataStore.deleteMilestone(milestoneData)
                    milestoneToDelete = nil
                }
            }
        } message: { milestoneData in
            Text("Are you sure you want to delete \"\(milestoneData.expectation.title ?? "this milestone")\"?")
        }
    }
}
