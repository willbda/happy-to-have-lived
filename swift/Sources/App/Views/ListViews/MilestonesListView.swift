//
// MilestonesListView.swift
// Written by Claude Code on 2025-11-19
//
// PURPOSE: List of milestones with upcoming dates
// DATA SOURCE: MilestonesListViewModel
// INTERACTIONS: Tap to view, swipe to delete, empty state
//

import Models
import Services
import SwiftUI

/// List view for milestones
///
/// **PATTERN**: ViewModel-based (same pattern as GoalsListView)
/// **DATA**: MilestonesListViewModel → MilestoneRepository → Database
/// **DISPLAY**: MilestoneRowView for each milestone
/// **INTERACTIONS**: Swipe to delete, pull to refresh
///
public struct MilestonesListView: View {
    @State private var viewModel = MilestonesListViewModel()

    @State private var showingAddMilestone = false
    @State private var milestoneToDelete: MilestoneWithDetails?
    @State private var showingDeleteAlert = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                ProgressView("Loading milestones...")
            } else if viewModel.milestones.isEmpty {
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
                    ForEach(viewModel.milestones) { milestoneData in
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddMilestone = true
                } label: {
                    Label("Add Milestone", systemImage: "plus")
                }
            }
        }
        .task {
            // Load milestones when view appears
            await viewModel.loadMilestones()
        }
        .refreshable {
            // Pull-to-refresh uses same load method
            await viewModel.loadMilestones()
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
                    await viewModel.deleteMilestone(milestoneData)
                }
            }
        } message: { milestoneData in
            Text("Are you sure you want to delete \"\(milestoneData.expectation.title ?? "this milestone")\"?")
        }
        .alert("Error", isPresented: .constant(viewModel.hasError)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
